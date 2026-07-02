-- 0011_instrumentation_dpa.sql — daily snapshots, keep-alive read, DPA deletion
--
-- Closes out the MVP: the success-metric / upgrade-trigger instrumentation, the
-- keep-alive's read path, and the Kenya DPA account-deletion capability.

-- 1. Full-deletion capability (DPA erasure) ----------------------------------
-- events.created_by / updated_by and event_audit_log.changed_by were ON DELETE
-- RESTRICT + NOT NULL, which blocks deleting a rep who scheduled lectures. Make
-- them nullable + ON DELETE SET NULL so a user can be fully erased while the
-- cohort's schedule + audit history are RETAINED (the author simply becomes
-- null). Deleting auth.users cascades to users (0001), which then set-nulls here.
alter table events alter column created_by drop not null;
alter table events drop constraint events_created_by_fkey;
alter table events add constraint events_created_by_fkey
  foreign key (created_by) references users (id) on delete set null;

alter table events drop constraint events_updated_by_fkey;
alter table events add constraint events_updated_by_fkey
  foreign key (updated_by) references users (id) on delete set null;

alter table event_audit_log alter column changed_by drop not null;
alter table event_audit_log drop constraint event_audit_log_changed_by_fkey;
alter table event_audit_log add constraint event_audit_log_changed_by_fkey
  foreign key (changed_by) references users (id) on delete set null;

-- 2. Account-deletion requests (manual fulfilment at MVP) --------------------
-- The surfaced DPA path: a user requests deletion; the owner fulfils it manually
-- (deleting auth.users triggers the cascade above). Rows are created by the
-- request-account-deletion Edge Function (service role); a user may read only
-- their own request (to show "deletion requested").
create table deletion_requests (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users (id) on delete cascade,
  status       text not null default 'pending',
  requested_at timestamptz not null default now()
);

alter table deletion_requests enable row level security;

create policy deletion_requests_select_own
  on deletion_requests for select
  to authenticated
  using (user_id = auth.uid());

grant select on deletion_requests to authenticated;

-- 3. daily_snapshots read access for the keep-alive --------------------------
-- keepalive.yml pings this with the anon key every 3 days. The rows are
-- AGGREGATE metrics only (MAU / cohort counts / DB size) — no personal data —
-- so exposing them read-only is acceptable and lets metrics be passively visible.
alter table daily_snapshots enable row level security;

create policy daily_snapshots_read_all
  on daily_snapshots for select
  to anon, authenticated
  using (true);

grant select on daily_snapshots to anon, authenticated;

-- 4. record_daily_snapshot() — the once/day metrics writer -------------------
-- SECURITY DEFINER so it can read auth.users (MAU) and pg_database_size. Upserts
-- today's row (idempotent — safe to run more than once a day). conflict_incidents
-- stays 0: venue/cohort clashes are rejected at the DB constraint level and not
-- logged, and zero is the goal (a rejection logger is out of MVP scope).
create or replace function public.record_daily_snapshot()
returns daily_snapshots
language plpgsql
security definer
set search_path = public
as $$
declare
  result daily_snapshots;
begin
  insert into daily_snapshots (
    snapshot_date, monthly_active_users, active_cohorts, db_size_bytes, conflict_incidents
  )
  values (
    current_date,
    (select count(*) from auth.users where last_sign_in_at > now() - interval '30 days'),
    (select count(distinct cohort_id) from events
       where created_at > now() - interval '14 days' and status <> 'canceled'),
    pg_database_size(current_database()),
    0
  )
  on conflict (snapshot_date) do update set
    monthly_active_users = excluded.monthly_active_users,
    active_cohorts       = excluded.active_cohorts,
    db_size_bytes        = excluded.db_size_bytes,
    conflict_incidents   = excluded.conflict_incidents
  returning * into result;
  return result;
end;
$$;

grant execute on function public.record_daily_snapshot() to service_role;
