# Edutime — Claude Code Context

## What This Project Is

Edutime is an Android-first mobile app (Flutter + Supabase) for lecture
scheduling at Chuka University. Class representatives schedule conflict-free
lectures to venues; students in their cohort see the schedule in real time and
get push notifications on changes. It is bottom-up (rep-driven), not a top-down
timetable. MVP target: end of September 2026, solo dev, zero budget. Open source
(MIT) so other universities can self-deploy. Full context: DISCOVERY.md,
ARCHITECTURE.md, PRESSURE-TEST.md.

## Current Status

- Active branch: `dev` (milestone branches created; no milestone started yet)
- Current milestone: none yet — next is `feature/01-auth-rls` (run `/code-branch`)
- Milestone goal: see MILESTONES.md → feature/01-auth-rls (auth + RLS, the DPA guarantee)

## Commands

```bash
fvm flutter pub get                     # install client deps
fvm flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
fvm flutter analyze                     # static analysis (must be clean)
fvm dart format .                       # format (CI checks --set-exit-if-changed)
fvm flutter test                        # widget/unit tests
supabase start                          # local stack (needs Supabase CLI + Docker)
supabase db reset                       # apply migrations/ + seed.sql
supabase functions serve <name>         # run an Edge Function locally
```

> Toolchain note: Flutter is via **FVM** (3.41.2). Supabase CLI + Docker are
> **not yet installed** — install before running the backend locally.

## Tech Stack

| Layer    | Choice | Notes |
| -------- | ------ | ----- |
| Client   | Flutter (Dart), BLoC | `table_calendar` for calendar views |
| Backend  | Supabase Edge Functions (Deno/TS) | UX layer only — NOT the authority |
| Database | Supabase Postgres + RLS | conflict rules enforced as DB constraints |
| Auth     | Supabase Auth (email/password) | role lives in `users` table, NOT the JWT |
| Realtime | Supabase Realtime | live calendar + venue availability |
| Push     | Firebase Cloud Messaging | dispatched by Edge Function on lecture change |
| Email    | Resend | transactional onboarding |
| Hosting  | Supabase managed + Google Play | ~$0/mo; $25 one-time Play fee |

## Project Structure

```
lib/
  main.dart            app bootstrap (Supabase init via --dart-define)
  app.dart             MaterialApp + theme + home
  core/                config (env), supabase client, theme
  data/models/         Dart models mirroring DB enums/tables
  data/repositories/   Supabase data access (RLS reads, realtime streams)
  features/<x>/         feature UI + BLoC (auth, calendar, cohort, venues)
test/                  widget/unit tests
supabase/migrations/   0001 schema, 0002 conflict constraints, 0003 RLS
supabase/functions/    Edge Functions (Deno) — currently 501 skeletons
supabase/seed.sql      venue registry seed (replace with real Chuka data)
.github/workflows/     ci.yml (analyze+test), keepalive.yml (anti-pause)
```

## Architecture Rules (non-negotiable)

- **The database is the source of truth for conflicts.** Venue and cohort
  overlap are enforced by Postgres `EXCLUDE` constraints (`0002`). Edge Functions
  and the Flutter client only pre-check for nice errors — never rely on them to
  prevent a double-booking.
- **RLS is the only authoritative access control.** No client-side role check is
  trusted. Role is read from the `users` table via `get_my_role()`
  (`SECURITY DEFINER`), never from the JWT.
- **Never expose another user's `email`.** A student reads only their own `users`
  row; cohort-mate lists come through `get_cohort_members()` (name + role only).
  This is the DPA guarantee — verify it before any other policy.
- **Lecture writes go through the `schedule-lecture` Edge Function**, which also
  writes the audit log. Reads go directly through the client under RLS.
- **Recurring lectures = one row per occurrence** sharing `recurrence_group_id`.
  `recurrence_rule` is display metadata only.

## Coding Conventions

- Dart 3.11 "tall" formatting via `dart format` — keep `flutter analyze` clean.
- Models extend `Equatable`; DB enum mapping lives in `*FromDb` helpers.
- Supabase access stays in `data/repositories/` — never query Supabase from
  widgets or BLoCs directly.
- State management is **BLoC** (sealed events + `Equatable` states).
- Edge Functions: one folder per function, shared code in `_shared/`.

## Environment Variables

All secrets live in `.env` (never committed). See `.env.example`:

- `SUPABASE_URL` / `SUPABASE_ANON_KEY` — client-safe; passed via `--dart-define`.
- `SUPABASE_SERVICE_ROLE_KEY` — server-side only (Edge Functions/CI). Never ship
  to the client.
- `FCM_PROJECT_ID` / `FCM_SERVER_KEY` — push notifications.
- `RESEND_API_KEY` — transactional email.
- `FCM_WEBHOOK_SECRET` — secures the DB webhook → `dispatch-fcm`.

## Milestone Plan

One branch = one milestone. Never work across two branches at once. Run
`/code-review` before merging and `/testing` before closing a milestone.
Build backend-first (per pressure-test): conflict constraint + RLS + FCM dispatch
before polishing UI. Full goals/acceptance criteria live in MILESTONES.md.

All feature branches come off `dev`; `dev` merges into `main` after testing.

| # | Branch | Milestone |
| - | ------ | --------- |
| 1 | `feature/01-auth-rls` | Auth + RLS foundation — `get_my_role()`, users read matrix, no cross-user `email` (the DPA guarantee). |
| 2 | `feature/02-cohorts` | Faculty/program/cohort + self-service join-by-code, remove-student, promote-class-rep. |
| 3 | `feature/03-scheduling` | Conflict-free scheduling — schedule/edit/cancel over the `EXCLUDE` constraints (core invariant). |
| 4 | `feature/04-calendar-realtime` | `table_calendar` day/week/semester views + live Realtime + offline cache. |
| 5 | `feature/05-notifications` | DB webhook → `dispatch-fcm` push + in-app notification history + device tokens. |
| 6 | `feature/06-instrumentation-polish` | `daily-snapshot` + keep-alive verification + DPA deletion path + offline/error polish. |

## Key Decisions (from ARCHITECTURE.md / PRESSURE-TEST.md)

- **Supabase over a custom backend** — zero cost, Postgres integrity + RLS,
  built-in realtime/auth, solo-maintainable. Accepted vendor dependency.
- **Cohort join = self-service join code + removal**, NOT an approval queue
  (approval contradicted instant-access adoption). `cohort_join_requests` is out.
- **Conflict enforcement in the DB**, not the Edge Function (avoids TOCTOU races
  and bypass). Edge/Flutter checks are UX only.
- **Free-tier keep-alive** via GitHub Actions cron every 3 days; hard upgrade
  trigger to Pro ($25/mo) at DB>400MB OR MAU>500 OR ≥3 cohorts/week for 7 days.
- **`daily_snapshots`** table is the instrumentation for both success metrics and
  the upgrade trigger — not a dashboard.

## Known Constraints

- Android-first; must degrade gracefully offline (cached schedule readable;
  writes require connectivity with clear feedback).
- Kenya Data Protection Act 2019: privacy notice at registration, surfaced
  deletion path, data minimization (name/email/cohort/role/prefs only), and the
  "independent student project, not official Chuka" disclaimer.
- Superadmin is infra-only (never a UI role); Faculty Reps are bootstrapped
  manually out-of-band.

## What Claude Should NOT Do

- Never enforce conflict rules only in app code — the DB constraint is ground truth.
- Never read/return another user's `email`, or build a student-visible roster.
- Never use `auth.jwt() -> 'role'` for access decisions — use `get_my_role()`.
- Never commit `.env`, `google-services.json`, or `firebase_options.dart`.
- Never build phase-2 scope into the MVP (branch/merge, combined lectures,
  faculty approval queues, unit registry, lecturer accounts, web app).
- Never change the schema by hand — add a numbered migration in `supabase/migrations/`.
