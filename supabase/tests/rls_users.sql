-- rls_users.sql — proves the DPA guarantee and the privilege-escalation guard.
--
-- Run against the local stack:
--   docker exec -i supabase_db_edutime psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
--     < supabase/tests/rls_users.sql
--
-- The whole script runs in a transaction and ROLLS BACK at the end, so it
-- leaves no data behind. Any failed assertion aborts with a non-zero exit
-- (ON_ERROR_STOP=1), which is how CI/the runner detects failure.
--
-- What it proves:
--   1. A student can read ONLY their own users row (never another user's email).
--   2. get_cohort_members() returns nothing for a non-class-rep, and never
--      exposes an email column at all.
--   3. A student cannot self-promote: updating their own role/cohort_id is
--      rejected by the privileged-column guard (0004).

begin;

-- Fixed UUIDs so we can impersonate via JWT claims below.
\set alice '11111111-1111-1111-1111-111111111111'
\set bob   '22222222-2222-2222-2222-222222222222'

-- Org scaffold + two cohorts.
insert into faculties (id, name)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'Test Faculty');
insert into programs (id, faculty_id, name, total_semesters)
values ('aaaaaaaa-0000-0000-0000-000000000002',
        'aaaaaaaa-0000-0000-0000-000000000001', 'Test Program', 8);
insert into cohorts (id, program_id, intake_year, current_semester, join_code)
values
  ('aaaaaaaa-0000-0000-0000-000000000003',
   'aaaaaaaa-0000-0000-0000-000000000002', 2025, 1, 'TST-C1'),
  ('aaaaaaaa-0000-0000-0000-000000000004',
   'aaaaaaaa-0000-0000-0000-000000000002', 2025, 1, 'TST-C2');

-- Create two auth accounts. The handle_new_user trigger (0004) creates the
-- matching public.users rows (role = student, cohort_id = null).
insert into auth.users (id, email, raw_user_meta_data) values
  (:'alice', 'alice@test.dev', '{"full_name":"Alice Test"}'::jsonb),
  (:'bob',   'bob@test.dev',   '{"full_name":"Bob Test"}'::jsonb);

-- Place them in DIFFERENT cohorts (as postgres — the guard allows trusted roles).
update users set cohort_id = 'aaaaaaaa-0000-0000-0000-000000000003' where id = :'alice';
update users set cohort_id = 'aaaaaaaa-0000-0000-0000-000000000004' where id = :'bob';

-- Sanity: the trigger really created both profiles with role student.
do $$
begin
  if (select count(*) from users where id in
        ('11111111-1111-1111-1111-111111111111',
         '22222222-2222-2222-2222-222222222222')) <> 2 then
    raise exception 'SETUP FAILED: handle_new_user did not create both profiles';
  end if;
end $$;

-- ── Impersonate Alice (a normal authenticated student) ─────────────────────
-- set_config (not SET) handles the dotted GUC name robustly; auth.uid() reads
-- the 'sub' claim from it. Claims are set before switching role.
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
  true);
set local role authenticated;

-- 1. DPA: Alice sees exactly one users row — her own — and never Bob's email.
do $$
declare
  visible_count int;
  bob_email_visible int;
begin
  select count(*) into visible_count from users;
  if visible_count <> 1 then
    raise exception 'FAIL(1a): student sees % user rows, expected 1', visible_count;
  end if;

  select count(*) into bob_email_visible
  from users where email = 'bob@test.dev';
  if bob_email_visible <> 0 then
    raise exception 'FAIL(1b): student can read another user''s email';
  end if;

  if not exists (select 1 from users where email = 'alice@test.dev') then
    raise exception 'FAIL(1c): student cannot read her own row';
  end if;
end $$;

-- 2. get_cohort_members(): a non-class-rep gets nothing (and the function
--    signature has no email column at all — enforced at definition time).
do $$
declare
  member_count int;
begin
  select count(*) into member_count from get_cohort_members();
  if member_count <> 0 then
    raise exception 'FAIL(2): non-class-rep got % cohort members, expected 0',
      member_count;
  end if;
end $$;

-- 3. Privilege guard: Alice cannot promote herself or move cohorts.
do $$
begin
  begin
    update users set role = 'class_rep' where id = auth.uid();
    raise exception 'FAIL(3a): student was able to self-promote to class_rep';
  exception
    when insufficient_privilege then null;  -- expected
  end;

  begin
    update users set cohort_id = 'aaaaaaaa-0000-0000-0000-000000000004'
      where id = auth.uid();
    raise exception 'FAIL(3b): student was able to change their own cohort_id';
  exception
    when insufficient_privilege then null;  -- expected
  end;
end $$;

-- 4. A benign self-update (full_name) is still allowed.
do $$
begin
  update users set full_name = 'Alice Renamed' where id = auth.uid();
  if not exists (select 1 from users where full_name = 'Alice Renamed') then
    raise exception 'FAIL(4): student could not update her own full_name';
  end if;
end $$;

reset role;

select 'ALL RLS USER TESTS PASSED' as result;

rollback;
