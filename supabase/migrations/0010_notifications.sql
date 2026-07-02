-- 0010_notifications.sql — device tokens + notification read access
--
-- Push dispatch is Edge-initiated: schedule/edit/cancel-lecture call the shared
-- notifyEventChange() (service role) after a successful write — one notification
-- per rep ACTION (a whole recurring series collapses to one), never per row.
-- So there is no DB webhook / trigger here.

-- Per-user FCM device tokens. The client upserts its OWN token on login/refresh
-- (decision: direct client upsert under RLS, no store-token function). PK on the
-- token so a device that re-registers under a new account reassigns cleanly.
create table device_tokens (
  token      text primary key,
  user_id    uuid not null references users (id) on delete cascade,
  platform   text,
  updated_at timestamptz not null default now()
);
create index device_tokens_user_idx on device_tokens (user_id);

alter table device_tokens enable row level security;

-- A user may read/write only their own tokens. USING + WITH CHECK both pin
-- user_id to auth.uid(), so a client can never register a token for someone else.
create policy device_tokens_own
  on device_tokens for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on device_tokens to authenticated;

-- notifications: rows are INSERTED by the service role (dispatch), so clients
-- need only read + mark-read. The 0003 policies (notifications_select_own /
-- _update_own) already scope this; the base grant was missing (a policy without
-- its grant still 403s). No insert grant — clients must not forge notifications.
grant select, update on notifications to authenticated;

-- Live in-app history / unread badge. RLS (notifications_select_own) governs
-- Realtime too, so a client only ever receives its own rows. REPLICA IDENTITY
-- FULL so RLS can filter the mark-as-read UPDATE reliably.
alter table public.notifications replica identity full;
alter publication supabase_realtime add table public.notifications;
