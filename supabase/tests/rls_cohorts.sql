-- rls_cohorts.sql — proves cohort reads are scoped to the caller's own cohort
-- (no join-code enumeration). Runs in a transaction and rolls back.
--
--   docker exec -i supabase_db_edutime psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/tests/rls_cohorts.sql

begin;

insert into faculties (id, name)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'RLS Test Faculty');
insert into programs (id, faculty_id, name, total_semesters)
values ('bbbbbbbb-0000-0000-0000-000000000002',
        'bbbbbbbb-0000-0000-0000-000000000001', 'RLS Test Program', 8);
insert into cohorts (id, program_id, intake_year, current_semester, join_code)
values
  ('bbbbbbbb-0000-0000-0000-000000000003',
   'bbbbbbbb-0000-0000-0000-000000000002', 2025, 1, 'RLSAAA'),
  ('bbbbbbbb-0000-0000-0000-000000000004',
   'bbbbbbbb-0000-0000-0000-000000000002', 2025, 1, 'RLSBBB');

insert into auth.users (id, email) values
  ('33333333-3333-3333-3333-333333333333', 'cohort-a@test.dev');
update users set cohort_id = 'bbbbbbbb-0000-0000-0000-000000000003'
  where id = '33333333-3333-3333-3333-333333333333';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
  true);

do $$
declare
  visible int;
  other_code int;
begin
  select count(*) into visible from cohorts;
  if visible <> 1 then
    raise exception 'FAIL: member sees % cohorts, expected only their own', visible;
  end if;

  select count(*) into other_code
  from cohorts where join_code = 'RLSBBB';
  if other_code <> 0 then
    raise exception 'FAIL: another cohort''s join_code is readable (enumeration)';
  end if;

  if not exists (select 1 from cohorts where join_code = 'RLSAAA') then
    raise exception 'FAIL: member cannot read their own cohort';
  end if;
end $$;

reset role;
select 'ALL RLS COHORT TESTS PASSED' as result;

rollback;
