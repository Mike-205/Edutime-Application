-- conflict_constraints.sql — the no-double-booking ground truth (0002).
--
--   docker exec -i supabase_db_edutime psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/tests/conflict_constraints.sql
--
-- Proves the EXCLUDE constraints reject overlapping bookings and that canceling
-- frees the slot. The constraints are GiST index-level, so they reject overlaps
-- atomically even under concurrent commits — a sequential attempt is enough to
-- prove the rule holds (no app logic is involved). Runs in a transaction and
-- rolls back.

begin;

insert into faculties (id, name)
values ('cccccccc-0000-0000-0000-000000000001', 'Conflict Test Faculty');
insert into programs (id, faculty_id, name, total_semesters)
values ('cccccccc-0000-0000-0000-000000000002',
        'cccccccc-0000-0000-0000-000000000001', 'Conflict Test Program', 8);
insert into cohorts (id, program_id, intake_year, current_semester, join_code)
values ('cccccccc-0000-0000-0000-000000000003',
        'cccccccc-0000-0000-0000-000000000002', 2025, 1, 'CNFTST');
insert into venues (id, name, type)
values ('cccccccc-0000-0000-0000-000000000004', 'Conflict Hall', 'lecture_hall');

insert into auth.users (id, email)
values ('44444444-4444-4444-4444-444444444444', 'rep@test.dev');
update users
  set role = 'class_rep', cohort_id = 'cccccccc-0000-0000-0000-000000000003'
  where id = '44444444-4444-4444-4444-444444444444';

-- Baseline lecture: 10:00–12:00 in Conflict Hall.
insert into lectures
  (cohort_id, unit_name, lecturer_name, venue_id, start_time, end_time, created_by)
values
  ('cccccccc-0000-0000-0000-000000000003', 'Algorithms', 'Dr A',
   'cccccccc-0000-0000-0000-000000000004',
   '2026-02-02 10:00+03', '2026-02-02 12:00+03',
   '44444444-4444-4444-4444-444444444444');

-- 1. Same venue, overlapping time -> rejected.
do $$
begin
  insert into lectures
    (cohort_id, unit_name, lecturer_name, venue_id, start_time, end_time, created_by)
  values
    ('cccccccc-0000-0000-0000-000000000003', 'Databases', 'Dr B',
     'cccccccc-0000-0000-0000-000000000004',
     '2026-02-02 11:00+03', '2026-02-02 13:00+03',
     '44444444-4444-4444-4444-444444444444');
  raise exception 'FAIL(1): overlapping venue booking was allowed';
exception
  when exclusion_violation then null;  -- expected
end $$;

-- 2. Same cohort, DIFFERENT venue, overlapping time -> still rejected.
insert into venues (id, name, type)
values ('cccccccc-0000-0000-0000-000000000005', 'Other Hall', 'lecture_hall');
do $$
begin
  insert into lectures
    (cohort_id, unit_name, lecturer_name, venue_id, start_time, end_time, created_by)
  values
    ('cccccccc-0000-0000-0000-000000000003', 'Networks', 'Dr C',
     'cccccccc-0000-0000-0000-000000000005',
     '2026-02-02 11:00+03', '2026-02-02 13:00+03',
     '44444444-4444-4444-4444-444444444444');
  raise exception 'FAIL(2): overlapping cohort booking was allowed';
exception
  when exclusion_violation then null;  -- expected
end $$;

-- 3. Canceling the baseline frees the venue + cohort slot.
update lectures set status = 'canceled' where unit_name = 'Algorithms';
do $$
begin
  insert into lectures
    (cohort_id, unit_name, lecturer_name, venue_id, start_time, end_time, created_by)
  values
    ('cccccccc-0000-0000-0000-000000000003', 'Databases', 'Dr B',
     'cccccccc-0000-0000-0000-000000000004',
     '2026-02-02 11:00+03', '2026-02-02 13:00+03',
     '44444444-4444-4444-4444-444444444444');
exception
  when exclusion_violation then
    raise exception 'FAIL(3): canceled lecture did not free the slot';
end $$;

select 'ALL CONFLICT CONSTRAINT TESTS PASSED' as result;

rollback;
