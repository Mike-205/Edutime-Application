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

/// Returns a readable conflict message if [slot] would clash with an existing
/// non-canceled lecture — by venue (any cohort) or by the caller's cohort (any
/// venue) — or null if the slot is free. [excludeId] skips a lecture being
/// edited. This is the UX pre-check; the DB EXCLUDE constraints remain the
/// authority (see findConstraintConflictMessage).
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
    .from("lectures")
    .select("id, unit_name, start_time, end_time, venue_id")
    .neq("status", "canceled")
    .lt("start_time", opts.slot.end)
    .gt("end_time", opts.slot.start)
    .or(`venue_id.eq.${opts.venueId},cohort_id.eq.${opts.cohortId}`);
  if (opts.excludeId) query = query.neq("id", opts.excludeId);

  const { data, error } = await query;
  if (error) throw error;
  if (!data || data.length === 0) return null;

  const clash = data[0];
  const window = `${hhmm(clash.start_time)}–${hhmm(clash.end_time)}`;
  return clash.venue_id === opts.venueId
    ? `That venue is taken by ${clash.unit_name} (${window}).`
    : `Your cohort already has ${clash.unit_name} (${window}) in that slot.`;
}

/// Postgres raises exclusion_violation (23P01) when an EXCLUDE constraint
/// rejects an overlapping insert/update — the race-proof ground truth behind
/// the pre-check. Maps it to the same readable message.
export function isExclusionViolation(error: unknown): boolean {
  return typeof error === "object" &&
    error !== null &&
    (error as { code?: string }).code === "23P01";
}
