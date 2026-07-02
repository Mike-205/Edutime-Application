// cancel-lecture — cancel a single occurrence or a whole recurring series.
// Class-rep-gated, own cohort only. Canceling frees the venue immediately
// (the EXCLUDE constraints ignore canceled rows).

import { corsHeaders, json } from "../_shared/cors.ts";
import { adminClient, getCallerId, getCallerProfile } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  const lectureId = body.lecture_id as string | undefined;
  const scope = body.scope === "series" ? "series" : "single";
  if (!lectureId) return json({ error: "lecture_id_required" }, 400);

  const admin = adminClient();
  const callerId = await getCallerId(req, admin);
  if (!callerId) return json({ error: "unauthorized" }, 401);
  const caller = await getCallerProfile(admin, callerId);
  if (!caller) return json({ error: "lookup_failed" }, 500);
  if (caller.role !== "class_rep" || !caller.cohortId) {
    return json({ error: "forbidden" }, 403);
  }

  const { data: existing, error: loadErr } = await admin
    .from("events")
    .select("id, cohort_id, recurrence_group_id")
    .eq("id", lectureId)
    .maybeSingle();
  if (loadErr) return json({ error: "lookup_failed" }, 500);
  if (!existing || existing.cohort_id !== caller.cohortId) {
    return json({ error: "not_in_your_cohort" }, 404);
  }

  // Select the rows to cancel: the one occurrence, or the whole series.
  let target = admin
    .from("events")
    .update({ status: "canceled" })
    .eq("cohort_id", caller.cohortId)
    .neq("status", "canceled");
  if (scope === "series" && existing.recurrence_group_id) {
    target = target.eq("recurrence_group_id", existing.recurrence_group_id);
  } else {
    target = target.eq("id", lectureId);
  }

  const { data: canceled, error: cancelErr } = await target.select();
  if (cancelErr) return json({ error: "cancel_failed" }, 500);

  await admin.from("event_audit_log").insert(
    (canceled ?? []).map((row) => ({
      event_id: row.id,
      action: "canceled",
      changed_by: callerId,
      snapshot: row,
    })),
  );

  return json({ canceled: canceled?.length ?? 0 }, 200);
});
