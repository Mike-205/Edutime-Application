-- 0009_events_realtime.sql — enable Realtime on events
--
-- The live calendar + venue-availability updates rely on the client's
-- .stream() over events (LectureRepository.watchMyCohort). A table only emits
-- Realtime changes if it is in the supabase_realtime publication — events was
-- never added (only users, in 0004), so live updates silently never fired.
--
-- RLS (events_select_own_cohort, 0003) governs Realtime too, so a client only
-- ever receives changes for its own cohort. REPLICA IDENTITY FULL makes the old
-- row image carry cohort_id, so RLS can be evaluated on UPDATE/DELETE (cancel
-- and edit are updates) and those changes are delivered reliably.
alter table public.events replica identity full;
alter publication supabase_realtime add table public.events;
