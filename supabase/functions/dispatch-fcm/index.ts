// dispatch-fcm — HTTP entry point for notifying a cohort of a lecture change.
//
// The PRIMARY path is in-process: schedule/edit/cancel-lecture call
// notifyEventChange() directly after a successful write (decision: Edge-initiated
// dispatch, one notification per action — a whole recurring series collapses to
// one). This function is a thin, secret-guarded wrapper over the SAME shared
// logic, for manual testing / replay / a future DB-webhook path. The FCM HTTP v1
// transport lives in ../_shared/fcm.ts (proven by fcm-poc).
//
// Body: { cohort_id, change_type, title?, course_id?, start_time, event_id?,
//         exclude_user_id? }. Guarded by the x-webhook-secret header.

import { corsHeaders, json } from "../_shared/cors.ts";
import { adminClient } from "../_shared/auth.ts";
import { ChangeType, notifyEventChange } from "../_shared/notify.ts";

const CHANGE_TYPES: ChangeType[] = ["created", "updated", "canceled"];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const secret = Deno.env.get("FCM_WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-webhook-secret") !== secret) {
    return json({ error: "unauthorized" }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_body" }, 400);
  }

  const cohortId = body.cohort_id as string | undefined;
  const changeType = body.change_type as ChangeType | undefined;
  const startTime = body.start_time as string | undefined;
  if (!cohortId || !changeType || !startTime) {
    return json({ error: "missing_fields" }, 400);
  }
  if (!CHANGE_TYPES.includes(changeType)) {
    return json({ error: "invalid_change_type" }, 400);
  }

  await notifyEventChange(adminClient(), {
    cohortId,
    changeType,
    title: (body.title as string | null | undefined) ?? null,
    courseId: (body.course_id as string | null | undefined) ?? null,
    startIso: startTime,
    eventId: (body.event_id as string | null | undefined) ?? null,
    excludeUserId: (body.exclude_user_id as string | null | undefined) ?? null,
  });

  return json({ ok: true }, 200);
});
