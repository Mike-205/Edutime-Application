// edit-lecture — re-check + update a single occurrence. Class-rep-gated, own
// cohort only. The EXCLUDE constraints remain the authority on the update.

import { corsHeaders, json } from "../_shared/cors.ts";
import { adminClient, getCallerId, getCallerProfile } from "../_shared/auth.ts";
import { findConflict, isExclusionViolation } from "../_shared/lectures.ts";

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
    .select("*")
    .eq("id", lectureId)
    .maybeSingle();
  if (loadErr) return json({ error: "lookup_failed" }, 500);
  if (!existing || existing.cohort_id !== caller.cohortId) {
    return json({ error: "not_in_your_cohort" }, 404);
  }
  if (existing.status === "canceled") {
    return json({ error: "lecture_canceled" }, 409);
  }

  // Effective values after the edit.
  const venueId = (body.venue_id as string | undefined) ?? existing.venue_id;
  const startTime = (body.start_time as string | undefined) ?? existing.start_time;
  const endTime = (body.end_time as string | undefined) ?? existing.end_time;
  if (Date.parse(endTime) <= Date.parse(startTime)) {
    return json({ error: "invalid_time_range" }, 400);
  }

  let message: string | null;
  try {
    message = await findConflict(admin, {
      cohortId: caller.cohortId,
      venueId,
      slot: { start: startTime, end: endTime },
      excludeId: lectureId,
    });
  } catch {
    return json({ error: "precheck_failed" }, 500);
  }
  if (message) return json({ error: "conflict", message }, 409);

  const patch: Record<string, unknown> = {
    venue_id: venueId,
    start_time: startTime,
    end_time: endTime,
  };
  if (typeof body.course_id === "string") patch.course_id = body.course_id;
  if (typeof body.title === "string") patch.title = body.title.trim() || null;
  if (typeof body.lecturer_name === "string") {
    patch.lecturer_name = body.lecturer_name.trim();
  }

  const { data: updated, error: updateErr } = await admin
    .from("events")
    .update(patch)
    .eq("id", lectureId)
    .select()
    .maybeSingle();
  if (updateErr) {
    if (isExclusionViolation(updateErr)) {
      return json({ error: "conflict", message: "That slot was just taken." }, 409);
    }
    return json({ error: "update_failed" }, 500);
  }

  await admin.from("event_audit_log").insert({
    event_id: lectureId,
    action: "updated",
    changed_by: callerId,
    snapshot: updated,
  });

  return json({ event: updated }, 200);
});
