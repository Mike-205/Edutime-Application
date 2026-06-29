-- 0006_cohort_read_scope.sql — close join-code enumeration
--
-- 0003 made cohorts readable by ALL authenticated users (cohorts_select_all).
-- That exposes every cohort's join_code to everyone, so any user could
-- enumerate codes and join any cohort — broader than the "a single leaked code
-- is low risk" assumption. Join-by-code is resolved server-side (the Edge
-- Function uses the service role), and a client only ever needs its OWN cohort,
-- so scope client cohort reads to the caller's cohort.
--
-- faculties/programs stay readable (select-all) — they carry no secret and are
-- needed to render program/faculty names via the cohort join.

drop policy if exists cohorts_select_all on public.cohorts;

create policy cohorts_select_own
  on public.cohorts for select
  to authenticated
  using (id = my_cohort_id());
