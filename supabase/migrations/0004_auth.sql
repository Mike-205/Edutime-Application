-- 0004_auth.sql — auth wiring for the users profile row
--
-- Two pieces deferred to the auth milestone by 0003:
--   1. handle_new_user(): create the public.users profile when a Supabase Auth
--      account is created. Role is hard-defaulted to 'student' here, server-side
--      — the client never chooses its own role.
--   2. protect_user_privileged_columns(): the BEFORE UPDATE guard referenced in
--      0003. The users_update_self policy lets a user edit their OWN row; without
--      this guard that row includes `role`, so a student could self-promote to
--      class_rep. This trigger makes role/cohort_id changeable only by the
--      service role (Edge Functions) — column-level enforcement RLS can't give.
--
-- Triggers fire even for the service-role key (which bypasses RLS but NOT
-- triggers), so the guard explicitly lets trusted roles through; otherwise the
-- promote-class-rep Edge Function (cohort milestone) could never change a role.

-- 1. Profile creation on signup ----------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, full_name)
  values (
    new.id,
    new.email,
    -- full_name is NOT NULL; the client always supplies it at registration,
    -- but fall back to the email local-part so signup can never 500 on a
    -- missing metadata field.
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      split_part(new.email, '@', 1)
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. Privileged-column guard --------------------------------------------------
-- SECURITY INVOKER (default) so current_user reflects the actual caller: the
-- Postgres role PostgREST set from the request JWT ('authenticated' / 'anon' /
-- 'service_role'). Direct DB/admin connections (postgres, supabase_admin) are
-- trusted; end-user connections are not.
create or replace function public.protect_user_privileged_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user in (
    'service_role', 'postgres', 'supabase_admin', 'supabase_auth_admin'
  ) then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'role may only be changed by the service role'
      using errcode = '42501';  -- insufficient_privilege
  end if;

  if new.cohort_id is distinct from old.cohort_id then
    raise exception 'cohort_id may only be changed by the service role'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger users_protect_privileged_columns
  before update on public.users
  for each row execute function public.protect_user_privileged_columns();

-- 3. Table privileges for the users policies ---------------------------------
-- RLS policies are inert without a base GRANT: the authenticated role needs
-- table privilege before its row-level policy can allow anything. SELECT/UPDATE
-- are still scoped to the caller's OWN row by users_select_self/users_update_self
-- (other rows — and their emails — remain entirely unreachable), and the
-- privileged-column guard above keeps role/cohort_id read-only here.
-- (Reference/lecture/notification grants are added by their own milestones.)
grant select, update on public.users to authenticated;

-- 4. Realtime on the users row ------------------------------------------------
-- A client subscribes to its own users row so a promotion (role change by the
-- service role) flips controls live, with no logout. RLS (users_select_self)
-- governs realtime too, so a client only ever receives its own row.
alter publication supabase_realtime add table public.users;
