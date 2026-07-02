// schedule-lecture — UX layer over the DB conflict constraints.
//
//   1. Readable pre-check; on a clash return a forwardable error before insert.
//   2. Materialize occurrences (one row per week for a recurring series, sharing
//      a recurrence_group_id) and insert them in one statement.
//   3. The EXCLUDE constraints are the ground truth: a race that slips past the
//      pre-check is caught as exclusion_violation and surfaced as the same
//      readable conflict.
//   4. Append an event_audit_log row per created occurrence.
// The database is the authority — never this function.

import { corsHeaders, json } from "../_shared/cors.ts";
import { adminClient, getCallerId, getCallerProfile } from "../_shared/auth.ts";
import { findConflict, isExclusionViolation, Slot } from "../_shared/lectures.ts";
import { dispatchAfterResponse } from "../_shared/notify.ts";

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_WEEKS = 26;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_body" }, 400);
  }

  const courseId = body.course_id as string | undefined;
  const title = (body.title as string | undefined)?.trim() || null;
  const lecturerName = (body.lecturer_name as string | undefined)?.trim();
  const venueId = body.venue_id as string | undefined;
  const startTime = body.start_time as string | undefined;
  const endTime = body.end_time as string | undefined;
  const weeks = Number(body.weeks ?? 1);

  if (!courseId || !lecturerName || !venueId || !startTime || !endTime) {
    return json({ error: "missing_fields" }, 400);
  }
  const startMs = Date.parse(startTime);
  const endMs = Date.parse(endTime);
  if (Number.isNaN(startMs) || Number.isNaN(endMs) || endMs <= startMs) {
    return json({ error: "invalid_time_range" }, 400);
  }
  if (!Number.isInteger(weeks) || weeks < 1 || weeks > MAX_WEEKS) {
    return json({ error: "invalid_weeks" }, 400);
  }

  const admin = adminClient();
  const callerId = await getCallerId(req, admin);
  if (!callerId) return json({ error: "unauthorized" }, 401);

  const caller = await getCallerProfile(admin, callerId);
  if (!caller) return json({ error: "lookup_failed" }, 500);
  if (caller.role !== "class_rep" || !caller.cohortId) {
    return json({ error: "forbidden" }, 403);
  }
  const cohortId = caller.cohortId;

  // Materialize occurrences (weekly).
  const recurring = weeks > 1;
  const groupId = recurring ? crypto.randomUUID() : null;
  const slots: Slot[] = [];
  for (let i = 0; i < weeks; i++) {
    slots.push({
      start: new Date(startMs + WEEK_MS * i).toISOString(),
      end: new Date(endMs + WEEK_MS * i).toISOString(),
    });
  }

  // Pre-check each occurrence for a readable error before any write.
  for (let i = 0; i < slots.length; i++) {
    let message: string | null;
    try {
      message = await findConflict(admin, {
        cohortId,
        venueId,
        slot: slots[i],
      });
    } catch {
      return json({ error: "precheck_failed" }, 500);
    }
    if (message) {
      return json({
        error: "conflict",
        message: recurring ? `Week ${i + 1}: ${message}` : message,
      }, 409);
    }
  }

  const rows = slots.map((slot) => ({
    cohort_id: cohortId,
    course_id: courseId,
    title,
    lecturer_name: lecturerName,
    venue_id: venueId,
    start_time: slot.start,
    end_time: slot.end,
    recurrence: recurring ? "weekly" : "none",
    recurrence_group_id: groupId,
    recurrence_rule: recurring ? `WEEKLY;COUNT=${weeks}` : null,
    created_by: callerId,
  }));

  const { data: inserted, error: insertErr } = await admin
    .from("events")
    .insert(rows)
    .select();
  if (insertErr) {
    // The constraint is the authority — a race that beat the pre-check lands here.
    if (isExclusionViolation(insertErr)) {
      return json({ error: "conflict", message: "That slot was just taken." }, 409);
    }
    return json({ error: "insert_failed" }, 500);
  }

  // Audit each created occurrence.
  await admin.from("event_audit_log").insert(
    (inserted ?? []).map((row) => ({
      event_id: row.id,
      action: "created",
      changed_by: callerId,
      snapshot: row,
    })),
  );

  // Notify the cohort — once for the whole action (series -> one notification),
  // after the response so the rep isn't blocked on the FCM fan-out.
  dispatchAfterResponse(admin, {
    cohortId,
    changeType: "created",
    title,
    courseId,
    startIso: slots[0].start,
    eventId: inserted?.[0]?.id ?? null,
    excludeUserId: callerId,
  });

  return json({ created: inserted?.length ?? 0, events: inserted }, 201);
});
