-- 0001_init.sql — Edutime core schema
-- Conceptual model: see ARCHITECTURE.md "Data Model (Draft)".
-- This migration defines structure only. Business logic (conflict detection
-- internals, FCM dispatch) lives in later migrations / Edge Functions.

-- Extensions -----------------------------------------------------------------
-- btree_gist is required for the venue-overlap EXCLUDE constraint (0002).
create extension if not exists btree_gist;

-- Enums ----------------------------------------------------------------------
create type user_role       as enum ('student', 'class_rep', 'faculty_rep');
create type program_level   as enum ('certificate', 'diploma', 'degree', 'master', 'phd');
create type cohort_pace     as enum ('bimester', 'trimester');
create type room_type       as enum ('lecture_hall', 'lab', 'conference_hall');
create type venue_type      as enum ('physical', 'online');
create type venue_platform  as enum ('google_meet', 'kenet', 'zoom');
create type recurrence_type as enum ('none', 'daily', 'weekly', 'monthly', 'yearly', 'custom');
-- Stored lifecycle only. "ongoing" / "past" / "upcoming" are DERIVED at read
-- time from now() vs start_time/end_time — never persisted (that would need a
-- cron and always be stale). 'rescheduled' is a forward hook; nothing writes it
-- yet (edit-lecture updates in place and leaves status = 'scheduled').
create type event_status    as enum ('scheduled', 'canceled', 'rescheduled');
create type audit_action    as enum ('created', 'updated', 'canceled');
create type notif_type      as enum ('created', 'updated', 'canceled');

-- Faculty --------------------------------------------------------------------
create table faculties (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  abbreviation  text not null,
  description   text,
  created_at    timestamptz not null default now()
);

-- Department --------------------------------------------------------------------
create table departments (
  id            uuid primary key default gen_random_uuid(),
  faculty_id    uuid not null references faculties (id) on delete cascade,
  name          text not null,
  description   text,
  created_at    timestamptz not null default now()
);

-- Program --------------------------------------------------------------------
create table programs (
  id                    uuid primary key default gen_random_uuid(),
  department_id         uuid not null references departments (id) on delete cascade,
  name                  text not null,
  abbreviation          text not null,
  code                  text not null,
  description           text,
  level                 program_level not null,
  duration_semesters    int  not null check (duration_semesters > 0),
  created_at            timestamptz not null default now()
);

-- Course (Unit) --------------------------------------------------------------------
create table courses (
  id                uuid primary key default gen_random_uuid(),
  program_id        uuid not null references programs (id) on delete cascade,
  name              text not null,
  abbreviation      text not null,
  description       text,
  semester_taught   int not null check (semester_taught > 0),
  -- nullable with check constraints for flexibility
  lecture_hours     int check (lecture_hours is null or lecture_hours > 0),
  credits           int check (credits is null or credits > 0),
  created_at        timestamptz not null default now()
);

-- Cohort ---------------------------------------------------------------------
-- name is composed by the cohort-creation Edge Function as
-- "<program.abbreviation> <intake_year>" (e.g. "BSC-CS 2026"); it is not a
-- generated column because it depends on a joined table. Stored for cheap reads.
create table cohorts (
  id                uuid primary key default gen_random_uuid(),
  program_id        uuid not null references programs (id) on delete restrict,
  name              text not null,
  join_code         text not null unique,
  intake_year       int not null,
  current_semester  int not null check (current_semester > 0),
  pace              cohort_pace not null default 'bimester',
  created_at        timestamptz not null default now()
);

-- Building -------------------------------------------------------------------
create table buildings (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  abbreviation text not null,
  description  text,
  image_url    text,
  created_at   timestamptz not null default now()
);

-- Room -----------------------------------------------------------------------
-- Rooms are building-specific: only the rooms a building actually has get a row
-- (e.g. Science Complex has 504/601-604; Business School R-wing does not). There
-- is no cross-product of building x number.
-- The display name (e.g. "S-101") is NOT stored — it is composed on read as
-- buildings.abbreviation || '-' || rooms.number, so it can never drift from the
-- building it belongs to. (A GENERATED column can't do this: it may only
-- reference same-table columns, and the abbreviation lives on buildings.)
create table rooms (
  id          uuid primary key default gen_random_uuid(),
  building_id uuid not null references buildings (id) on delete cascade,
  number      text not null,
  capacity    int check (capacity is null or capacity > 0),
  room_type   room_type not null,
  created_at  timestamptz not null default now(),
  -- A building cannot repeat a room number.
  constraint rooms_building_number_unique unique (building_id, number)
);

-- Venue ----------------------------------------------------------------------
-- Conflict model (the invariant the whole app protects):
--   * PHYSICAL venues are SHARED reference data — exactly one venue row per room
--     (venues_room_idx below). Two events pointing at that room share venue_id,
--     so the 0002 EXCLUDE on venue_id catches the double-booking. Correct.
--   * ONLINE venues are created PER EVENT (a fresh row per meeting link). They
--     therefore never share venue_id, so the same EXCLUDE never fires falsely —
--     online capacity is effectively unlimited and must not "conflict".
-- This split is why the EXCLUDE can stay keyed on venue_id alone with no
-- type-aware WHERE clause. Do not point two events at one online venue row.
create table venues (
  id            uuid primary key default gen_random_uuid(),
  type          venue_type not null,
  room_id       uuid references rooms (id) on delete set null,
  meeting_link  text,
  platform      venue_platform,
  label         text,
  created_at    timestamptz not null default now(),
  -- physical => must have a room; online => must have a link. Guard the split.
  constraint venues_physical_has_room
    check (type <> 'physical' or room_id is not null),
  constraint venues_online_has_link
    check (type <> 'online' or meeting_link is not null)
);

-- Ground truth for conflict detection: one room maps to at most one venue.
-- Required for the 0002/0003 EXCLUDE constraints to catch double-bookings.
create unique index venues_room_idx on venues (room_id) where room_id is not null;

-- User -----------------------------------------------------------------------
-- id mirrors auth.users.id. role is authoritative for RLS (never the JWT).
-- reg_number is NULLABLE: faculty_reps (and the infra superadmin) have no
-- student registration number. It is additional PII beyond the DPA-minimal set
-- (name/email/cohort/role/prefs) — collect it only for students and surface it
-- in the privacy notice. See PRESSURE-TEST.md "Data minimization".
-- department_id / faculty_id are for users NOT tied to a cohort (faculty_reps);
-- for a student they are DERIVABLE via cohort -> program -> department -> faculty
-- and may be left null. Do not treat them as the source of truth for a student's
-- faculty — resolve through the cohort chain to avoid drift.
create table users (
  id            uuid primary key references auth.users (id) on delete cascade,
  email         text not null,
  full_name     text not null,
  reg_number    text,
  role          user_role not null default 'student',
  cohort_id     uuid references cohorts (id) on delete set null,
  department_id uuid references departments (id) on delete set null,
  faculty_id    uuid references faculties (id) on delete set null,
  created_at    timestamptz not null default now()
);

-- Event ----------------------------------------------------------------------
-- Materialized occurrences (one row per occurrence; recurrence_rule is display
-- metadata only). The unit is FK'd to courses.id for integrity/reporting; this
-- means a course must be seeded for the cohort's program before it can be
-- scheduled (accepted seeding dependency). lecturer_name stays FREE TEXT —
-- lecturer accounts remain Phase 2. title is an optional custom label.
create table events (
  id                    uuid primary key default gen_random_uuid(),
  cohort_id             uuid not null references cohorts (id) on delete cascade,
  title                 text,
  venue_id              uuid not null references venues (id) on delete restrict,
  course_id             uuid not null references courses (id) on delete restrict,
  lecturer_name         text not null,
  start_time            timestamptz not null,
  end_time              timestamptz not null,
  recurrence            recurrence_type not null default 'none',
  recurrence_rule       text, -- Store iCal RRULE strings
  recurrence_group_id   uuid,
  status                event_status not null default 'scheduled',
  created_by            uuid not null references users (id) on delete restrict,
  updated_by            uuid references users (id) on delete restrict,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint events_time_order check (end_time > start_time)
);

create index events_cohort_idx   on events (cohort_id);
create index events_venue_idx    on events (venue_id);
create index events_course_idx   on events (course_id);
create index events_group_idx    on events (recurrence_group_id);
-- Calendar reads are always "this cohort, this date window": composite index.
create index events_calendar_idx on events (cohort_id, start_time, end_time);
-- Conflict EXCLUDE constraints (venue + cohort overlap) are added in 0002.

-- EventAuditLog --------------------------------------------------------------
-- Append-only. snapshot holds event state (JSON) at the time of the action.
create table event_audit_log (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references events (id) on delete cascade,
  action     audit_action not null,
  changed_by uuid not null references users (id) on delete restrict,
  changed_at timestamptz not null default now(),
  snapshot   jsonb not null
);

-- Notification ---------------------------------------------------------------
create table notifications (
  -- Consideration: For large cohorts, individual inserts may be slow.
  -- Consider a 'broadcast_notifications' table for system-wide/cohort-wide alerts.
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users (id) on delete cascade,
  event_id   uuid references events (id) on delete set null,
  title      text not null,
  message    text not null,
  type       notif_type not null,
  read_at    timestamptz,
  created_at timestamptz not null default now()
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