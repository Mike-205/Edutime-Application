-- 0001_init.sql — Edutime core schema
-- Conceptual model: see ARCHITECTURE.md "Data Model (Draft)".
-- This migration defines structure only. Business logic (conflict detection
-- internals, FCM dispatch) lives in later migrations / Edge Functions.

-- Extensions -----------------------------------------------------------------
-- btree_gist is required for the venue-overlap EXCLUDE constraint (0003).
create extension if not exists btree_gist;

-- Enums ----------------------------------------------------------------------
create type user_role     as enum ('student', 'class_rep', 'faculty_rep');
create type venue_type     as enum ('lecture_hall', 'lab', 'tutorial_room', 'online');
create type lecture_status as enum ('scheduled', 'canceled', 'rescheduled');
create type audit_action   as enum ('created', 'updated', 'canceled');
create type notif_type     as enum ('new', 'updated', 'canceled');

-- Faculty --------------------------------------------------------------------
create table faculties (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  created_at  timestamptz not null default now()
);

-- Program --------------------------------------------------------------------
create table programs (
  id              uuid primary key default gen_random_uuid(),
  faculty_id      uuid not null references faculties (id) on delete restrict,
  name            text not null,
  description     text,
  total_semesters int  not null check (total_semesters > 0),
  created_at      timestamptz not null default now()
);

-- Cohort ---------------------------------------------------------------------
-- Immutable once created. join_code is regeneratable, non-expiring at MVP.
create table cohorts (
  id               uuid primary key default gen_random_uuid(),
  program_id       uuid not null references programs (id) on delete restrict,
  intake_year      int  not null,
  current_semester int  not null check (current_semester > 0),
  join_code        text not null unique,
  created_at       timestamptz not null default now()
);

-- User -----------------------------------------------------------------------
-- id mirrors auth.users.id. role is authoritative for RLS (never the JWT).
create table users (
  id            uuid primary key references auth.users (id) on delete cascade,
  email         text not null,
  full_name     text not null,
  role          user_role not null default 'student',
  cohort_id     uuid references cohorts (id) on delete set null,
  created_at    timestamptz not null default now()
);

-- Venue ----------------------------------------------------------------------
create table venues (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  capacity   int  check (capacity is null or capacity > 0),
  type       venue_type not null,
  building   text,
  created_at timestamptz not null default now()
);

-- Lecture --------------------------------------------------------------------
-- Recurring series: one row per occurrence, linked by recurrence_group_id.
-- recurrence_rule is display/regeneration metadata only — not the source of
-- truth. The materialized rows are. Conflict enforcement is added in 0003.
create table lectures (
  id                  uuid primary key default gen_random_uuid(),
  cohort_id           uuid not null references cohorts (id) on delete cascade,
  unit_name           text not null,                 -- free text at MVP, no FK
  lecturer_name       text not null,
  venue_id            uuid not null references venues (id) on delete restrict,
  start_time          timestamptz not null,
  end_time            timestamptz not null,
  recurrence_group_id uuid,
  recurrence_rule     text,
  status              lecture_status not null default 'scheduled',
  created_by          uuid not null references users (id) on delete restrict,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint lectures_time_order check (end_time > start_time)
);

create index lectures_cohort_idx    on lectures (cohort_id);
create index lectures_venue_idx     on lectures (venue_id);
create index lectures_group_idx     on lectures (recurrence_group_id);

-- LectureAuditLog ------------------------------------------------------------
-- Append-only. snapshot holds lecture state (JSON) at the time of the action.
create table lecture_audit_log (
  id         uuid primary key default gen_random_uuid(),
  lecture_id uuid not null references lectures (id) on delete cascade,
  action     audit_action not null,
  changed_by uuid not null references users (id) on delete restrict,
  changed_at timestamptz not null default now(),
  snapshot   jsonb not null
);

-- Notification ---------------------------------------------------------------
create table notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users (id) on delete cascade,
  lecture_id uuid references lectures (id) on delete set null,
  type       notif_type not null,
  sent_at    timestamptz not null default now(),
  read_at    timestamptz
);

create index notifications_user_idx on notifications (user_id);

-- daily_snapshots ------------------------------------------------------------
-- Instrumentation for the success metrics + free-tier upgrade trigger.
-- Populated once/day by a scheduled Edge Function. Not a dashboard.
create table daily_snapshots (
  id                   uuid primary key default gen_random_uuid(),
  snapshot_date        date not null unique,
  monthly_active_users int  not null default 0,
  active_cohorts       int  not null default 0,
  db_size_bytes        bigint not null default 0,
  conflict_incidents   int  not null default 0,
  created_at           timestamptz not null default now()
);