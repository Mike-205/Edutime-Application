-- conflict_constraints.sql — the no-double-booking ground truth (0002).
--
--   docker exec -i supabase_db_edutime psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/tests/conflict_constraints.sql
--
-- Proves the EXCLUDE constraints (events_no_venue_overlap +
-- events_no_cohort_overlap) reject overlapping bookings and that canceling
-- frees the slot. The constraints are GiST index-level, so they reject overlaps
-- atomically even under concurrent commits — a sequential attempt is enough to
-- prove the rule holds (no app logic is involved). Runs in a transaction and
-- rolls back.

begin;

-- Academic hierarchy: faculty -> department -> program -> course, + cohort.
insert into faculties (id, name, abbreviation)
values ('cccccccc-0000-0000-0000-000000000001', 'Conflict Test Faculty', 'CTF');
insert into departments (id, faculty_id, name)
values ('cccccccc-0000-0000-0000-000000000010',
        'cccccccc-0000-0000-0000-000000000001', 'Conflict Test Dept');
insert into programs
  (id, department_id, name, abbreviation, code, level, duration_semesters)
values ('cccccccc-0000-0000-0000-000000000002',
        'cccccccc-0000-0000-0000-000000000010',
        'Conflict Test Program', 'CTP', 'CTP-01', 'degree', 8);
insert into courses (id, program_id, name, abbreviation, semester_taught)
values ('cccccccc-0000-0000-0000-000000000020',
        'cccccccc-0000-0000-0000-000000000002', 'Algorithms', 'ALG', 1),
       ('cccccccc-0000-0000-0000-000000000021',
        'cccccccc-0000-0000-0000-000000000002', 'Databases', 'DB', 1),
       ('cccccccc-0000-0000-0000-000000000022',
        'cccccccc-0000-0000-0000-000000000002', 'Networks', 'NET', 1);
insert into cohorts
  (id, program_id, name, join_code, intake_year, current_semester)
values ('cccccccc-0000-0000-0000-000000000003',
        'cccccccc-0000-0000-0000-000000000002', 'CTP 2025', 'CNFTST', 2025, 1);

-- Physical venues: building -> room -> venue (one venue row per room).
insert into buildings (id, name, abbreviation)
values ('cccccccc-0000-0000-0000-000000000030', 'Conflict Complex', 'CC');
insert into rooms (id, building_id, number, room_type)
values ('cccccccc-0000-0000-0000-000000000040',
        'cccccccc-0000-0000-0000-000000000030', '101', 'lecture_hall'),
       ('cccccccc-0000-0000-0000-000000000041',
        'cccccccc-0000-0000-0000-000000000030', '102', 'lecture_hall');
insert into venues (id, type, room_id)
values ('cccccccc-0000-0000-0000-000000000004', 'physical',
        'cccccccc-0000-0000-0000-000000000040'),
       ('cccccccc-0000-0000-0000-000000000005', 'physical',
        'cccccccc-0000-0000-0000-000000000041');

insert into auth.users (id, email)
values ('44444444-4444-4444-4444-444444444444', 'rep@test.dev');
update users
  set role = 'class_rep', cohort_id = 'cccccccc-0000-0000-0000-000000000003'
  where id = '44444444-4444-4444-4444-444444444444';

-- Baseline event: 10:00–12:00, room 101, course Algorithms.
insert into events
  (cohort_id, course_id, lecturer_name, venue_id, start_time, end_time, created_by)
values
  ('cccccccc-0000-0000-0000-000000000003',
   'cccccccc-0000-0000-0000-000000000020', 'Dr A',
   'cccccccc-0000-0000-0000-000000000004',
   '2026-02-02 10:00+03', '2026-02-02 12:00+03',
   '44444444-4444-4444-4444-444444444444');

-- 1. Same venue, overlapping time -> rejected (events_no_venue_overlap).
do $$
begin
  insert into events
    (cohort_id, course_id, lecturer_name, venue_id, start_time, end_time, created_by)
  values
    ('cccccccc-0000-0000-0000-000000000003',
     'cccccccc-0000-0000-0000-000000000021', 'Dr B',
     'cccccccc-0000-0000-0000-000000000004',
     '2026-02-02 11:00+03', '2026-02-02 13:00+03',
     '44444444-4444-4444-4444-444444444444');
  raise exception 'FAIL(1): overlapping venue booking was allowed';
exception
  when exclusion_violation then null;  -- expected
end $$;

-- 2. Same cohort, DIFFERENT venue, overlapping time -> still rejected
--    (events_no_cohort_overlap).
do $$
begin
  insert into events
    (cohort_id, course_id, lecturer_name, venue_id, start_time, end_time, created_by)
  values
    ('cccccccc-0000-0000-0000-000000000003',
     'cccccccc-0000-0000-0000-000000000022', 'Dr C',
     'cccccccc-0000-0000-0000-000000000005',
     '2026-02-02 11:00+03', '2026-02-02 13:00+03',
     '44444444-4444-4444-4444-444444444444');
  raise exception 'FAIL(2): overlapping cohort booking was allowed';
exception
  when exclusion_violation then null;  -- expected
end $$;

-- 3. Canceling the baseline frees the venue + cohort slot.
update events set status = 'canceled'
  where course_id = 'cccccccc-0000-0000-0000-000000000020';
do $$
begin
  insert into events
    (cohort_id, course_id, lecturer_name, venue_id, start_time, end_time, created_by)
  values
    ('cccccccc-0000-0000-0000-000000000003',
     'cccccccc-0000-0000-0000-000000000021', 'Dr B',
     'cccccccc-0000-0000-0000-000000000004',
     '2026-02-02 11:00+03', '2026-02-02 13:00+03',
     '44444444-4444-4444-4444-444444444444');
exception
  when exclusion_violation then
    raise exception 'FAIL(3): canceled event did not free the slot';
end $$;

select 'ALL CONFLICT CONSTRAINT TESTS PASSED' as result;

rollback;
