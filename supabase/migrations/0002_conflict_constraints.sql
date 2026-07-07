-- 0002_conflict_constraints.sql — the no-double-booking ground truth
--
-- Enforcement hierarchy (ARCHITECTURE.md):
--   Postgres constraint (ground truth)  <-- THIS FILE
--   -> Edge Function pre-check (readable error)
--   -> Flutter pre-check (instant UX)
-- Nothing overrides these constraints. They are race-proof and bypass-proof:
-- two reps booking the same venue in the same second cannot both succeed.
--
-- Both rules are expressed as GiST EXCLUDE constraints over the time range.
-- Canceled events are excluded via the partial WHERE clause, so a canceled
-- event immediately frees its venue.

-- Venue conflict: no two non-canceled events share a venue with overlapping
-- time ranges. Overlap = new_start < existing_end AND new_end > existing_start,
-- which is exactly the && (range overlap) operator.
--
-- Keyed on venue_id alone (no venue-type WHERE): physical venues are one row per
-- room (venues_room_idx in 0001) so sharing a room => same venue_id => conflict;
-- online venues are created per event so they never share venue_id and never
-- collide. See the venues comment in 0001 for the full rule.
alter table events
  add constraint events_no_venue_overlap
  exclude using gist (
    venue_id with =,
    tstzrange(start_time, end_time) with &&
  )
  where (status <> 'canceled');

-- Cohort conflict: a cohort may not have two overlapping events, regardless of
-- venue (this rule DOES apply to online lectures — a cohort can't be in two
-- places at once).
alter table events
  add constraint events_no_cohort_overlap
  exclude using gist (
    cohort_id with =,
    tstzrange(start_time, end_time) with &&
  )
  where (status <> 'canceled');

-- No lecturer-overlap constraint: lecturer_name is free text (typo-prone) and
-- lecturer accounts are Phase 2. Revisit when lecturers become FK'd entities.
--
-- Note: each occurrence of a recurring series is its own row, so the
-- constraints check every occurrence individually with no extra logic.