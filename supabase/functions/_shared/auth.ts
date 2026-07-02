import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

/// Service-role client — bypasses RLS. Every Edge Function that uses it MUST
/// enforce its own authorization (resolve the caller, check their role) before
/// mutating data.
export function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/// Resolves the caller's user id from their bearer JWT. Returns null when the
/// token is missing or invalid. Never trusts a client-supplied id.
export async function getCallerId(
  req: Request,
  admin: SupabaseClient,
): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const { data, error } = await admin.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );
  if (error || !data.user) return null;
  return data.user.id;
}

export interface CallerProfile {
  id: string;
  role: "student" | "class_rep" | "faculty_rep";
  cohortId: string | null;
}

/// Loads the caller's role + cohort from the users table (service role).
export async function getCallerProfile(
  admin: SupabaseClient,
  userId: string,
): Promise<CallerProfile | null> {
  const { data, error } = await admin
    .from("users")
    .select("id, role, cohort_id")
    .eq("id", userId)
    .maybeSingle();
  if (error || !data) return null;
  return { id: data.id, role: data.role, cohortId: data.cohort_id };
}
