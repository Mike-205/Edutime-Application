# Architecture Design — Edutime

> Technical blueprint. Every choice traces back to a finding in
> [DISCOVERY.md](DISCOVERY.md). This is the design we build from — to be
> stress-tested in `/pressure-test` (step 3) before any code is written.

## Project Type

- **Platform:** Mobile, **Android-first** (iOS available for free via Flutter
  but secondary for QA priority). Mobile-only for MVP — no web app.
- **Rendering:** Native compiled client (Flutter/Dart), talking to a managed
  backend (Supabase) over HTTPS + WebSocket (Realtime).
- **Target scale at launch:** Small — first ~3 active cohorts, against a
  university population of ~20,000 and ~5–10 Faculty Reps. Free-tier
  infrastructure is sufficient for MVP.
- **Offline:** Must degrade gracefully. Students can view a **cached schedule**
  offline; write operations (schedule/edit) require connectivity and must show
  clear offline feedback.

## Tech Stack

| Layer            | Choice                                          | Reason |
|------------------|-------------------------------------------------|--------|
| Client           | **Flutter (Dart)**                              | Single codebase, Android-first with free iOS path; runs in Android Studio; strong offline + real-time support. |
| State management | **BLoC**                                        | Developer is comfortable with it; predictable, testable, scales to real-time streams. |
| Calendar UI      | Custom widget on **`table_calendar`**           | Day/week/semester views required by the student journey. |
| Auth             | **Supabase Auth** (email/password, JWT claims)  | Built-in, free, role claim carried in JWT; integrates with RLS. |
| Database         | **Supabase Postgres** (+ RLS)                   | Relational data with strong integrity (constraints), real-time, and row-level isolation — matches the cross-cohort data-isolation requirement. |
| Real-time        | **Supabase Realtime**                           | Live calendar + venue-availability updates (the "within seconds" journey). |
| Server logic     | **Supabase Edge Functions** (Deno/TypeScript)   | Readable conflict errors, FCM dispatch — UX layer on top of DB enforcement. |
| File storage     | **Supabase Storage**                            | Profile photos; future attachments. |
| Push             | **Firebase Cloud Messaging (FCM)**              | Free push to Android/iOS; named in discovery. |
| Email            | **Resend**                                      | Transactional onboarding email; free tier 3,000/mo covers MVP. |
| Hosting          | **Supabase managed** (backend) + **Google Play** (client) | $0 backend; Play Store ($25 one-time) for trusted, auto-updating installs. |
| CI/CD            | **GitHub Actions + Supabase CLI**               | Automated tests + migration/edge-function deploy. |
| Repo / license   | **Public GitHub, MIT**                          | Open-source from day one so other universities can fork and self-deploy. |

## Architecture Overview

Edutime is a thin Flutter client over a managed Supabase backend. The client
authenticates with Supabase Auth and holds a JWT carrying the user's role
(`student` / `class_rep` / `faculty_rep`). All data access is mediated by
**Row Level Security** — the client is never trusted to enforce permissions, so
a student physically cannot read another cohort's data or write a lecture, even
with a tampered client. This is the technical realization of the discovery
security property: *a cohort's schedule is modifiable only by a Faculty-Rep-
promoted account.*

The calendar and venue-availability views are driven by **Supabase Realtime**
subscriptions: when a class rep schedules, edits, or cancels a lecture, every
subscribed student's calendar reflects it within seconds, and the affected venue
flips between available/occupied immediately. The same change triggers an **Edge
Function** that sends an **FCM** push (new / updated / canceled) and records a
`Notification` row for in-app history.

The most critical invariant — **no venue double-booking** — is enforced by the
**database itself**, not application code. A Postgres `EXCLUDE` constraint makes
overlapping venue bookings physically impossible to insert (race-proof,
bypass-proof); a `BEFORE INSERT/UPDATE` trigger/function adds the readable
cohort-conflict check and friendly error payloads. Edge Functions and the
Flutter client run *pre-checks* purely for UX — nothing overrides the
constraint.

## Access Control (RLS)

Role is read from the **`User` table**, never the JWT. Every role-branching
policy calls `get_my_role()` (`SELECT role FROM users WHERE id = auth.uid()`),
which **must be `SECURITY DEFINER` + `STABLE`** to read role without
re-triggering RLS on `users` (otherwise: infinite-recursion errors). JWT carries
identity (`auth.uid()`) only. Promotion is a live `users.role` update — no
logout; the client flips controls via a Realtime subscription on the user's own
row.

`User`-table read matrix (the DPA guarantee — implement and test **before** any
other policy is considered complete):

| Reader | May read | Of whom | `email`? |
|---|---|---|---|
| Student | own row only | self | own only |
| Class rep | `user_id, full_name, role` | users in own cohort | **no** |
| Faculty rep | `user_id, full_name, role` | class reps in own faculty | **no** |
| Superadmin | all | all | yes (infra only) |

- **No role reads another user's `email`.** `email` is write-once at
  registration, readable only by the owning user and the superadmin.
- Because RLS is row-level, the email restriction needs **column-level**
  enforcement — expose cohort-mates through a **view** that omits `email`, or
  use column `GRANT`s. The member-list UI shows `full_name` + `role` only;
  remove-member operates on `user_id`.
- A leaked join code therefore exposes only schedule data (not personal data
  under the DPA) — contained risk.

## Data Flow — Core Action (Class rep schedules a lecture)

1. **Flutter** — rep fills the lecture form (unit, lecturer, venue, time,
   optional recurrence). Client runs a local pre-check against the cohort's
   cached schedule for instant feedback (UX only).
2. **Edge Function (pre-check)** — client calls the schedule Edge Function. It
   runs the conflict query and, if it spots a clash, returns a readable error
   ("Venue *Lab 2* is taken by *DBMS* 10:00–12:00") *before* attempting a write.
3. **Insert under DB enforcement** — on pass, the write hits Postgres. For a
   one-time lecture, one row. For a recurring series, **one row per occurrence**
   sharing a `recurrence_group_id`; each occurrence is checked individually.
4. **Database is the authority** — the `EXCLUDE` constraint rejects any
   overlapping venue booking atomically (even two reps racing in the same
   second); the trigger enforces the cohort-overlap rule. A rejected write
   surfaces as a conflict error — the constraint is ground truth.
5. **Audit** — a successful create/edit/cancel appends a `LectureAuditLog` row
   (action, actor, timestamp, JSON snapshot of lecture state).
6. **Realtime fan-out** — the row change pushes over Supabase Realtime to all
   subscribed students; calendars and venue availability update within seconds.
7. **Notification** — a DB change webhook invokes the FCM Edge Function, which
   sends push (new/updated/canceled) and writes a `Notification` row for in-app
   history.

**Enforcement hierarchy:** Postgres constraint (ground truth) → Edge Function
pre-check (readable error) → Flutter pre-check (instant UX). Nothing overrides
the constraint.

## Data Model (Draft)

Conceptual overview — authoritative schema lives in migration files.

- **Faculty** — top-level org unit. `id, name, description, created_at`.
  Has many Programs.
- **Program** — course of study within a faculty, fixed number of semesters.
  `id, faculty_id, name, description, total_semesters, created_at`.
- **Cohort** — students who enrolled in the same program in the same intake
  year. **Immutable** once created; a student belongs to exactly one.
  `id, program_id, intake_year, current_semester, join_code, created_at`.
  - `join_code` — short alphanumeric code generated on cohort creation,
    **regeneratable** by the class rep (in case of leak), **non-expiring** at
    MVP. Entering a valid code adds the student to the cohort immediately. There
    is **no approval queue** — the class rep's remove-student action is the
    safety valve.
- **User** — every person. Role stored here, enforced via RLS.
  `id, email, full_name, role (student|class_rep|faculty_rep), cohort_id,
  created_at`.
- **Venue** — bookable room or online space.
  `id, name, capacity, type (lecture_hall|lab|tutorial_room|online), building,
  created_at`.
- **Lecture** — central entity; a scheduled academic event.
  `id, cohort_id, unit_name (free text — no unit FK at MVP), lecturer_name,
  venue_id, start_time, end_time, recurrence_group_id (nullable),
  recurrence_rule (nullable, display/regeneration metadata only),
  status (scheduled|canceled|rescheduled), created_by, created_at, updated_at`.
  - **Recurring series:** each occurrence is its **own row**, linked by a shared
    `recurrence_group_id` UUID. A 14-week series = 14 rows. Editing the series
    updates all rows sharing the id, each re-checked for conflicts.
  - **Constraint:** a `tstzrange(start_time, end_time)` + `venue_id` GiST
    `EXCLUDE` constraint (`btree_gist`) forbids overlapping venue bookings;
    canceled lectures are excluded from the constraint/checks.
- **LectureAuditLog** — append-only change log.
  `id, lecture_id, action (created|updated|canceled), changed_by, changed_at,
  snapshot (JSON)`.
- **Notification** — sent-push record + in-app history.
  `id, user_id, lecture_id, type (new|updated|canceled), sent_at, read_at`.

### Conflict detection rules (DB-enforced)

- **Venue conflict:** no two non-canceled lectures share a `venue_id` with
  overlapping ranges. Overlap = `new_start < existing_end AND new_end >
  existing_start`. Enforced by the `EXCLUDE` constraint.
- **Cohort conflict:** a cohort may not have two overlapping lectures regardless
  of venue. Enforced by trigger/function (readable error).
- **Recurring:** every occurrence passes both checks independently; a recurrence
  rule never overrides conflict detection.
- **Canceled lectures** are excluded from all checks; a canceled venue is
  immediately available again.

## API Surface (Draft)

Most reads go directly through the Supabase client under RLS (no custom
endpoints). Mutations with business logic go through **Edge Functions**:

- `POST schedule-lecture` — pre-check + insert (one-time or recurring series).
- `POST edit-lecture` — re-check + update (single occurrence or whole
  `recurrence_group_id`).
- `POST cancel-lecture` — set status `canceled`, free the venue, fire
  notification.
- `POST join-cohort-by-code` — student enters a join code → immediate cohort
  membership (no approval). `POST remove-student` / `POST regenerate-join-code`
  — class-rep gated.
- `POST promote-class-rep` — Faculty-Rep-only promotion (the sole path to
  class-rep authority).
- `POST create-program` — Faculty-Rep-only.
- `POST request-account-deletion` — surfaces the DPA deletion path (manual
  fulfillment at MVP; backend capable of full personal-data deletion).
- **DB webhook → `dispatch-fcm`** — fires FCM + writes `Notification` rows on
  lecture changes.
- **Reads via RLS:** cohort lectures, calendar ranges, venue availability,
  notification history, profile.

## Third-Party Services

| Service | Purpose | Integration |
|---|---|---|
| Supabase | Auth, Postgres, Realtime, Edge Functions, Storage | Supabase CLI + client SDK |
| Firebase Cloud Messaging | Push notifications | FCM SDK in Flutter; dispatched by Edge Function |
| Resend | Transactional onboarding email | API call from Edge Function |
| Google Play | App distribution (closed testing → public) | Play Console ($25 one-time) |
| GitHub | Public repo + CI/CD | GitHub Actions + Supabase CLI |

## Infrastructure & Cost Estimate

- **Backend:** Supabase **free tier** (sufficient for ~3 cohorts at launch).
- **Push:** FCM — free.
- **Email:** Resend free tier (3,000/mo).
- **Repo/CI:** GitHub + Actions — free for public repos.
- **Distribution:** Google Play — **$25 one-time**.
- **Estimated monthly cost at launch scale: ~$0** (one-time $25 Play fee).
- **Free-tier keep-alive:** a GitHub Actions cron (every 3 days) runs a
  lightweight authenticated query to prevent the 7-day inactivity pause, and
  logs the latest `daily_snapshots` row to the Actions output.
- **Upgrade trigger (hard rule → Supabase Pro $25/mo, pre-accepted):** any of
  the following true for 7 consecutive days — DB > 400MB, MAU > 500, or ≥3
  cohorts scheduling in the same week.
- **`daily_snapshots` table** — scheduled Edge Function records MAU, active
  cohort count, and DB-size estimate once/day. Not a dashboard; a queryable log
  for the upgrade trigger and the discovery success metrics (also houses
  `conflict_incidents`).
- **Environments:** local (Supabase CLI / local stack) → production Supabase
  project. A dedicated staging project is optional at MVP given free-tier
  project limits — to confirm at pressure-test.
- **Deferred (phase 2, only when load justifies):** Upstash Redis (venue
  availability cache), Fly.io/Railway (containerized backend if Edge Functions
  become limiting), PostHog (analytics).

## Developer Tooling

- **Language:** Dart (Flutter client) + TypeScript (Edge Functions, Deno).
- **Package manager:** `pub` (Flutter); Deno for functions.
- **State management:** BLoC.
- **Linting/formatting:** `flutter analyze` + `dart format`; lint Edge Functions
  with Deno's built-in tooling.
- **Testing:** Flutter widget/unit tests; Postgres-level tests for conflict
  constraints (the critical path); Edge Function tests.
- **Migrations:** Supabase CLI migration files (authoritative schema).
- **Monorepo:** single repo, no monorepo tooling needed at MVP.

## Key Design Decisions (Fixed for MVP)

- **Cohorts are immutable** — represent real intake groups; no movement between
  cohorts (branching deferred to phase 2; must not influence MVP model).
- **No enforced unit codes** — lectures reference units by free-text name; no
  units table/FK at MVP (removes class-rep setup burden).
- **Class-rep approval for cohort join** — students request, rep approves;
  prevents ghost students and wrong-cohort placement.
- **RLS is mandatory and sole authority** — no client-side role check is
  authoritative.
- **Offline tolerance** — cached schedule readable offline; writes require
  connectivity with clear feedback.
- **Android first** — iOS included via Flutter but secondary for QA.
- **Open source from day one** — public, MIT, no proprietary deps that block
  forking; goal is other universities self-deploying.

## Known Edge Cases (handle gracefully at MVP)

- **Last-minute venue change** → edit fires a fresh notification with new venue.
- **Two reps editing the same lecture** → last write wins; both see refreshed
  state; no merge UI.
- **Student in wrong cohort** → rep removes them; student re-applies to correct
  cohort.
- **Lecture canceled after student left for venue** → notification fires
  immediately; no guarantee of timely receipt; audit log records cancel time
  (real-world limitation, not a bug).
- **Faculty Rep unavailable to approve** → only affects class-rep promotion at
  MVP (branch/merge deferred); acceptable.
- **Semester misconfigured** → rep corrects it; no cascade (units not formally
  linked at MVP).

## Decisions Log

| Decision | Options Considered | Choice | Reason |
|---|---|---|---|
| Client framework | Native Android (Kotlin), Flutter, React Native | **Flutter** | Single codebase, Android-first + free iOS path, runs in Android Studio, strong offline/real-time. |
| Backend | Custom server (Node/Fly), Firebase, **Supabase** | **Supabase** | Zero cost, Postgres integrity + RLS isolation, built-in Realtime + Auth, solo-maintainable. |
| Conflict enforcement | Edge-Function check only; **DB constraint + trigger** | **DB constraint + trigger** | Edge-only is race-prone (TOCTOU) and bypassable; `EXCLUDE` constraint makes double-booking physically impossible — directly protects the "zero double-bookings" success metric. |
| Recurring lectures | Single row + RRULE expansion; **row per occurrence** | **Row per occurrence** (`recurrence_group_id`) | Keeps `EXCLUDE` constraint simple; trivial per-occurrence cancellation and per-occurrence conflict checks. |
| State management | Provider, Riverpod, **BLoC** | **BLoC** | Developer comfort; predictable, testable, suits real-time streams. |
| Push | OneSignal, **FCM** | **FCM** | Free, native to Flutter/Android, named in discovery. |
| Email | SES, **Resend** | **Resend** | Simple API, free 3,000/mo covers MVP. |
| Distribution | Direct APK sideload, **Google Play** | **Google Play** (closed testing → public) | Trusted install + auto-update; $25 one-time fee accepted; lowest adoption friction. |
| Cohort join | Rep-approval queue, **join code + removal** | **Join code + removal** | Approval gate contradicts instant-access adoption need; removal-not-approval avoids orientation-week bottleneck; wrong-cohort self-corrects. |
| Role enforcement source | JWT claim, **`User` table via `get_my_role()`** | **`User` table** | Instant, seamless promotion (no stale JWT / forced logout); lookup cost negligible at scale. |

## Open Technical Questions

Resolved in `/pressure-test` (see [PRESSURE-TEST.md](PRESSURE-TEST.md)):
- ✅ **Role enforcement** — `User` table is authoritative; `get_my_role()`
  (`SECURITY DEFINER` + `STABLE`); live promotion, no logout. See Access Control.
- ✅ **Cohort join** — approval gate removed; self-service join code + remove.
- ✅ **`User`-table data exposure** — read matrix above; no cross-user `email`.
- ✅ **Timeline** — build backend-first (developer is Flutter-strong,
  Supabase-lighter).
- ✅ **Free-tier pause / upgrade trigger** — keep-alive cron + hard numeric rule.

Still open — to settle during build:

1. **FCM dispatch mechanism.** Confirm trigger path: Supabase **Database
   Webhook → Edge Function → FCM** (recommended) vs. `pg_net` from a trigger.
   Also: how device FCM tokens are stored/refreshed per user.
2. **Staging environment.** Whether to run a separate staging Supabase project
   (free-tier project limits) or test against local + production only at MVP.
3. **Faculty Rep email type** (carried from discovery) — `@chuka.ac.ke` vs.
   `@student.chuka.ac.ke`; manual superadmin verification covers the trust gap.
4. **Recurrence horizon.** How far ahead a recurring series materializes (e.g.
   one semester) and how/when it's extended.
