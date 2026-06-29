-- 0007_lectures.sql — lecture read grants + updated_at maintenance
--
-- Lecture writes go through the schedule/edit/cancel Edge Functions (service
-- role), so no client write grant is added — the 0003 lectures_write_class_rep
-- policy stays as defense in depth. Reads are direct under RLS
-- (lectures_select_own_cohort), which needs the base SELECT grant.

grant select on public.lectures to authenticated;
grant select on public.lecture_audit_log to authenticated;
-- Venues are reference data (the lecture form's venue picker reads them); the
-- 0003 venues_select_all policy needs the base grant.
grant select on public.venues to authenticated;

-- Keep updated_at honest on every edit (the audit log is the full history;
-- this is just the row's last-touched stamp).
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger lectures_touch_updated_at
  before update on public.lectures
  for each row execute function public.touch_updated_at();
