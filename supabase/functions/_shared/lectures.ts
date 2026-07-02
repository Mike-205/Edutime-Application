import { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/// One scheduled time slot. ISO 8601 strings (UTC).
export interface Slot {
  start: string;
  end: string;
}

function hhmm(iso: string): string {
  // Show the time in the users' timezone (Chuka is EAT), not UTC, so the
  // conflict message matches what the rep typed.
  return new Date(iso).toLocaleTimeString("en-GB", {
    timeZone: "Africa/Nairobi",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/// A readable label for a clashing event: its custom title if set, else the
/// course abbreviation, else a generic fallback. The embedded `course` may be
/// returned by PostgREST as an object or a single-element array.
function eventLabel(clash: Record<string, unknown>): string {
  if (typeof clash.title === "string" && clash.title.trim()) return clash.title;
  const c = clash.course;
  const course = (Array.isArray(c) ? c[0] : c) as
    | { abbreviation?: string; name?: string }
    | null;
  return course?.abbreviation ?? course?.name ?? "a lecture";
}

/// Returns a readable conflict message if [slot] would clash with an existing
/// non-canceled event — by venue (any cohort) or by the caller's cohort (any
/// venue) — or null if the slot is free. [excludeId] skips an event being
/// edited. This is the UX pre-check; the DB EXCLUDE constraints remain the
/// authority (see isExclusionViolation).
export async function findConflict(
  admin: SupabaseClient,
  opts: {
    cohortId: string;
    venueId: string;
    slot: Slot;
    excludeId?: string;
  },
): Promise<string | null> {
  let query = admin
    .from("events")
    .select("id, title, start_time, end_time, venue_id, course:courses(abbreviation, name)")
    .neq("status", "canceled")
    .lt("start_time", opts.slot.end)
    .gt("end_time", opts.slot.start)
    .or(`venue_id.eq.${opts.venueId},cohort_id.eq.${opts.cohortId}`);
  if (opts.excludeId) query = query.neq("id", opts.excludeId);

  const { data, error } = await query;
  if (error) throw error;
  if (!data || data.length === 0) return null;

  const clash = data[0];
  const label = eventLabel(clash);
  const window = `${hhmm(clash.start_time)}–${hhmm(clash.end_time)}`;
  return clash.venue_id === opts.venueId
    ? `That venue is taken by ${label} (${window}).`
    : `Your cohort already has ${label} (${window}) in that slot.`;
}

/// Postgres raises exclusion_violation (23P01) when an EXCLUDE constraint
/// rejects an overlapping insert/update — the race-proof ground truth behind
/// the pre-check. Maps it to the same readable message.
export function isExclusionViolation(error: unknown): boolean {
  return typeof error === "object" &&
    error !== null &&
    (error as { code?: string }).code === "23P01";
}
