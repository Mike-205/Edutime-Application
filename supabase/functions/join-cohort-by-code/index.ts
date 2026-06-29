// join-cohort-by-code — self-service cohort join (no approval queue).
//
// Auth: the caller's JWT (verify_jwt = true). We read their id from the token,
// then use the service-role client to resolve the cohort and set
// users.cohort_id. Joining is rejected if the caller is already in a cohort —
// the rep's remove-student action is how a mis-placed student switches.

import { corsHeaders, json } from "../_shared/cors.ts";
import { adminClient, getCallerId, getCallerProfile } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let joinCode: unknown;
  try {
    ({ join_code: joinCode } = await req.json());
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  if (typeof joinCode !== "string" || joinCode.trim() === "") {
    return json({ error: "join_code_required" }, 400);
  }
  const code = joinCode.trim().toUpperCase();

  const admin = adminClient();
  const callerId = await getCallerId(req, admin);
  if (!callerId) return json({ error: "unauthorized" }, 401);

  const profile = await getCallerProfile(admin, callerId);
  if (!profile) return json({ error: "lookup_failed" }, 500);
  // Reject if already in a cohort — switching requires removal by a rep first.
  if (profile.cohortId) return json({ error: "already_in_cohort" }, 409);

  const { data: cohort, error: cohortErr } = await admin
    .from("cohorts")
    .select("id, program_id, intake_year, current_semester")
    .eq("join_code", code)
    .maybeSingle();
  if (cohortErr) return json({ error: "lookup_failed" }, 500);
  if (!cohort) return json({ error: "invalid_code" }, 404);

  // Join (service role bypasses RLS; the privileged-column guard allows it).
  const { error: updateErr } = await admin
    .from("users")
    .update({ cohort_id: cohort.id })
    .eq("id", callerId);
  if (updateErr) return json({ error: "join_failed" }, 500);

  return json({ cohort }, 200);
});
