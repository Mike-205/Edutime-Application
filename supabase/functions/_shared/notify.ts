import { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { sendPushMulti } from "./fcm.ts";

export type ChangeType = "created" | "updated" | "canceled";

export interface EventChange {
  cohortId: string;
  changeType: ChangeType;
  /** Optional custom event title; falls back to the course abbreviation. */
  title?: string | null;
  courseId?: string | null;
  /** Start of the (first) occurrence, for the message — ISO 8601. */
  startIso: string;
  eventId?: string | null;
  /** The acting rep — excluded from recipients (no push for your own change). */
  excludeUserId?: string | null;
}

/// Notifies a cohort's students of an event change: writes one in-app
/// notifications row per recipient AND sends one batched FCM push. Called ONCE
/// per rep action (a whole recurring series -> one notification), never per
/// occurrence (decision: one-per-action coalescing). Best-effort: a failure here
/// must never fail the originating write, so everything is wrapped and swallowed.
export async function notifyEventChange(
  admin: SupabaseClient,
  change: EventChange,
): Promise<void> {
  try {
    const { title, body } = await _compose(admin, change);

    // Recipients: everyone in the cohort except the acting rep.
    const { data: users } = await admin
      .from("users")
      .select("id")
      .eq("cohort_id", change.cohortId);
    const userIds = (users ?? [])
      .map((u) => u.id as string)
      .filter((id) => id !== change.excludeUserId);
    if (userIds.length === 0) return;

    // In-app history — one row per recipient.
    await admin.from("notifications").insert(
      userIds.map((uid) => ({
        user_id: uid,
        event_id: change.eventId ?? null,
        title,
        message: body,
        type: change.changeType,
      })),
    );

    // Push — one invocation, fanned out to every recipient's device tokens.
    const { data: tokens } = await admin
      .from("device_tokens")
      .select("token")
      .in("user_id", userIds);
    const list = (tokens ?? []).map((t) => t.token as string);
    if (list.length === 0) return;

    const results = await sendPushMulti(list, title, body, {
      type: change.changeType,
      event_id: change.eventId ?? "",
    });

    // Prune tokens FCM reports as dead so they don't accumulate.
    const dead = results.filter((r) => r.unregistered).map((r) => r.token);
    if (dead.length > 0) {
      await admin.from("device_tokens").delete().in("token", dead);
    }
  } catch (_) {
    // Best-effort: never let a notification failure fail the write.
  }
}

async function _compose(
  admin: SupabaseClient,
  change: EventChange,
): Promise<{ title: string; body: string }> {
  let label = change.title?.trim() || null;
  if (!label && change.courseId) {
    const { data } = await admin
      .from("courses")
      .select("abbreviation, name")
      .eq("id", change.courseId)
      .maybeSingle();
    label = (data?.abbreviation as string | undefined) ??
      (data?.name as string | undefined) ?? null;
  }
  label ??= "A lecture";

  const heading = change.changeType === "created"
    ? "New lecture"
    : change.changeType === "updated"
    ? "Lecture updated"
    : "Lecture canceled";
  const when = _whenEat(change.startIso);
  const body = change.changeType === "canceled"
    ? `${label} (${when}) was canceled`
    : `${label} · ${when}`;
  return { title: heading, body };
}

// Chuka is EAT — show the local time the rep set, not UTC.
function _whenEat(iso: string): string {
  return new Date(iso).toLocaleString("en-GB", {
    timeZone: "Africa/Nairobi",
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}
