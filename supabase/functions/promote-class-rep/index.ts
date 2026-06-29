// promote-class-rep — a faculty rep promotes a cohort student to class rep
// (the sole path to class-rep authority). Faculty-rep-gated.
//
// LIMITATION (flag for review/pressure-test): the data model has no
// user -> faculty link, so we cannot yet scope a faculty rep to "their" faculty.
// At MVP any faculty rep may promote any cohort student. Tightening this needs a
// faculty association on users (a future faculty milestone).

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

  const caller = await getCallerProfile(admin, callerId);
  if (!caller) return json({ error: "lookup_failed" }, 500);
  if (caller.role !== "faculty_rep") return json({ error: "forbidden" }, 403);

  const { data: target, error: targetErr } = await admin
    .from("users")
    .select("id, role, cohort_id")
    .eq("id", targetId)
    .maybeSingle();
  if (targetErr) return json({ error: "lookup_failed" }, 500);
  if (!target) return json({ error: "user_not_found" }, 404);
  if (!target.cohort_id) return json({ error: "target_has_no_cohort" }, 400);
  if (target.role !== "student") return json({ error: "already_privileged" }, 409);

  const { error: updateErr } = await admin
    .from("users")
    .update({ role: "class_rep" })
    .eq("id", targetId);
  if (updateErr) return json({ error: "promote_failed" }, 500);

  return json({ promoted: targetId, role: "class_rep" }, 200);
});
