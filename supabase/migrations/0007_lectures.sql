-- 0007_lectures.sql — event read grants + updated_at maintenance
--
-- Event writes go through the schedule/edit/cancel Edge Functions (service
-- role), so no client write grant is added — the 0003 events_write_class_rep
-- policy stays as defense in depth. Reads are direct under RLS
-- (events_select_own_cohort), which needs the base SELECT grant.

grant select on public.events to authenticated;
grant select on public.event_audit_log to authenticated;

-- Reference data read by the schedule form's pickers. A policy without the
-- matching base GRANT still 403s, so grant every table 0003 opened for select.
grant select on public.venues to authenticated;
grant select on public.buildings to authenticated;
grant select on public.rooms to authenticated;
grant select on public.departments to authenticated;
grant select on public.courses to authenticated;

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

create trigger events_touch_updated_at
  before update on public.events
  for each row execute function public.touch_updated_at();
