-- 0005_cohorts.sql — cohort read access + join-code generation
--
-- Membership mutations (join by code, remove student, regenerate code, promote
-- to class rep) all go through Edge Functions using the service-role key, which
-- bypasses RLS. So this migration adds NO client write policies — clients stay
-- read-only on these tables. It only:
--   1. grants the base read privilege the 0003 select policies need, and
--   2. adds a collision-safe join-code generator used by regenerate-join-code
--      (and out-of-band cohort creation).

-- 1. Read grants for the 0003 select-all policies -----------------------------
-- faculties/programs/cohorts are reference data every authenticated user may
-- read (resolve program/cohort info; the rep shares the join code). Without the
-- GRANT the permissive RLS policy still denies. See the auth milestone for the
-- same RLS-needs-a-grant pattern on users.
grant select on public.faculties to authenticated;
grant select on public.programs  to authenticated;
grant select on public.cohorts   to authenticated;

-- 2. Join-code generator ------------------------------------------------------
-- Short, human-shareable, unambiguous (no 0/O/1/I/L). Loops until unique. Used
-- only by the service role (regenerate-join-code Edge Function / admin cohort
-- creation), so it does not need to be granted to client roles.
create or replace function public.gen_unique_join_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
  i int;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.cohorts where join_code = code);
  end loop;
  return code;
end;
$$;
