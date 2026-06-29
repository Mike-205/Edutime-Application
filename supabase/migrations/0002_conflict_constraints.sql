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
-- Canceled lectures are excluded via the partial WHERE clause, so a canceled
-- lecture immediately frees its venue.

-- Venue conflict: no two non-canceled lectures share a venue with overlapping
-- time ranges. Overlap = new_start < existing_end AND new_end > existing_start,
-- which is exactly the && (range overlap) operator.
alter table lectures
  add constraint lectures_no_venue_overlap
  exclude using gist (
    venue_id with =,
    tstzrange(start_time, end_time) with &&
  )
  where (status <> 'canceled');

-- Cohort conflict: a cohort may not have two overlapping lectures, regardless
-- of venue.
alter table lectures
  add constraint lectures_no_cohort_overlap
  exclude using gist (
    cohort_id with =,
    tstzrange(start_time, end_time) with &&
  )
  where (status <> 'canceled');

-- Note: each occurrence of a recurring series is its own row, so the
-- constraints check every occurrence individually with no extra logic.