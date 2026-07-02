-- 0003_rls.sql — Row Level Security: the authoritative access layer
--
-- Role is read from the users table, NEVER from the JWT. Every role-branching
-- policy calls get_my_role(). The helper is SECURITY DEFINER + STABLE so it can
-- read users.role WITHOUT re-triggering RLS on users (otherwise: infinite
-- recursion). See ARCHITECTURE.md "Access Control (RLS)".
--
-- NOTE: Edge Functions use the service-role key, which BYPASSES RLS. These
-- policies govern direct client (anon/authenticated) access — defense in depth.

-- Helpers --------------------------------------------------------------------
create or replace function get_my_role()
returns user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.users where id = auth.uid();
$$;

create or replace function my_cohort_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select cohort_id from public.users where id = auth.uid();
$$;

-- Enable RLS everywhere (default-deny once enabled) --------------------------
alter table faculties        enable row level security;
alter table departments      enable row level security;
alter table programs         enable row level security;
alter table courses          enable row level security;
alter table cohorts          enable row level security;
alter table buildings        enable row level security;
alter table rooms            enable row level security;
alter table venues           enable row level security;
alter table users            enable row level security;
alter table events           enable row level security;
alter table event_audit_log  enable row level security;
alter table notifications    enable row level security;
alter table daily_snapshots  enable row level security;
-- daily_snapshots: no policies => no client access. Service role only.

-- USERS — the DPA read matrix ------------------------------------------------
-- A student/any role reads ONLY their own row from the base table. No roster.
-- Cohort-mate visibility (class rep / faculty rep) is exposed ONLY through the
-- get_cohort_members()/get_faculty_class_reps() functions below, which omit the
-- email column entirely. This is the column-level enforcement the base table
-- cannot give us.
create policy users_select_self
  on users for select
  using (id = auth.uid());

-- Self profile update, but NOT role/cohort (those are service-role only via
-- Edge Functions). Guard added in the auth milestone via a BEFORE UPDATE
-- trigger that rejects role/cohort_id changes from non-service callers.
create policy users_update_self
  on users for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- Cohort-mate directory for class reps: full_name + role only, NEVER email.
create or replace function get_cohort_members()
returns table (user_id uuid, full_name text, role user_role)
language sql
stable
security definer
set search_path = public
as $$
  select u.id, u.full_name, u.role
  from public.users u
  where u.cohort_id = my_cohort_id()
    and get_my_role() = 'class_rep';
$$;

-- REFERENCE DATA — the academic + venue hierarchy is readable by all
-- authenticated users (the schedule/venue pickers read it); every table here is
-- seeded via the service role only, never written by clients at MVP.
create policy venues_select_all      on venues      for select to authenticated using (true);
create policy buildings_select_all   on buildings   for select to authenticated using (true);
create policy rooms_select_all       on rooms       for select to authenticated using (true);

-- FACULTIES / DEPARTMENTS / PROGRAMS / COURSES — readable by all authenticated.
-- Writes are restricted to faculty reps / service role (faculty milestone).
create policy faculties_select_all   on faculties   for select to authenticated using (true);
create policy departments_select_all on departments for select to authenticated using (true);
create policy programs_select_all    on programs    for select to authenticated using (true);
create policy courses_select_all     on courses     for select to authenticated using (true);

-- COHORTS — readable by all authenticated (needed to resolve a join code and
-- to display program/cohort info). Cohort creation is a class-rep action,
-- completed in the cohort milestone.
create policy cohorts_select_all on cohorts for select to authenticated using (true);

-- EVENTS — a user reads events for their own cohort. Only a class rep of that
-- cohort may write. Students can never write an event record.
create policy events_select_own_cohort
  on events for select
  using (cohort_id = my_cohort_id());

create policy events_write_class_rep
  on events for all
  using (get_my_role() = 'class_rep' and cohort_id = my_cohort_id())
  with check (get_my_role() = 'class_rep' and cohort_id = my_cohort_id());

-- AUDIT LOG — readable by the class rep of the cohort; inserts via service role.
create policy audit_select_class_rep
  on event_audit_log for select
  using (
    get_my_role() = 'class_rep'
    and exists (
      select 1 from events e
      where e.id = event_audit_log.event_id
        and e.cohort_id = my_cohort_id()
    )
  );

-- NOTIFICATIONS — a user reads and marks read only their own notifications.
create policy notifications_select_own
  on notifications for select
  using (user_id = auth.uid());

create policy notifications_update_own
  on notifications for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());