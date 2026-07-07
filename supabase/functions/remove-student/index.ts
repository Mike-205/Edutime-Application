// remove-student — a class rep removes a student from their own cohort
// (the safety valve that replaces an approval queue). Class-rep-gated; can only
// remove a student in the caller's own cohort, never another rep or themselves.

import { corsHeaders, json } from "../_shared/cors.ts";
import { adminClient, getCallerId, getCallerProfile } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let targetId: unknown;
  try {
    ({ user_id: targetId } = await req.json());
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  if (typeof targetId !== "string" || targetId.trim() === "") {
    return json({ error: "user_id_required" }, 400);
  }

  const admin = adminClient();
  const callerId = await getCallerId(req, admin);
  if (!callerId) return json({ error: "unauthorized" }, 401);
  if (targetId === callerId) return json({ error: "cannot_remove_self" }, 400);

  const caller = await getCallerProfile(admin, callerId);
  if (!caller) return json({ error: "lookup_failed" }, 500);
  if (caller.role !== "class_rep" || !caller.cohortId) {
    return json({ error: "forbidden" }, 403);
  }

  const { data: target, error: targetErr } = await admin
    .from("users")
    .select("id, role, cohort_id")
    .eq("id", targetId)
    .maybeSingle();
  if (targetErr) return json({ error: "lookup_failed" }, 500);
  if (!target || target.cohort_id !== caller.cohortId) {
    return json({ error: "not_in_your_cohort" }, 404);
  }
  // A rep removes students only — not a fellow rep.
  if (target.role !== "student") return json({ error: "cannot_remove_rep" }, 403);

  const { error: updateErr } = await admin
    .from("users")
    .update({ cohort_id: null })
    .eq("id", targetId);
  if (updateErr) return json({ error: "remove_failed" }, 500);

  return json({ removed: targetId }, 200);
});
