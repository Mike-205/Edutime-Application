# Project Discovery — Edutime

> Non-technical discovery document. Captures the problem, people, and desired
> outcome. No technical decisions are made here — those belong to
> `/discovery-technical` (step 2).

## Problem Statement

Lecture scheduling at Chuka University (Kenya) is informal and unreliable.
Lecturers and class representatives negotiate venues and times verbally, and
that information travels through WhatsApp groups and word of mouth — both
asynchronous and untrustworthy. The result: students miss classes, waste time
searching for venues, arrive at double-booked rooms, and have no single,
trustworthy source of truth for where and when their lectures are happening.
There is also no way for a student to know which rooms are currently free for
personal study. Roughly 20,000 students are affected, in an environment of
variable internet connectivity, Android-dominant devices, and zero
institutional budget.

## Target Users

**Primary — Student (regular).** Every account starts here. A student is a
consumer of schedule information: they view their cohort's upcoming lectures
(venue, lecturer, time, status), browse a calendar (day/week/semester), receive
push notifications on changes, check real-time venue availability, and manage
profile/notification preferences. Students never create or modify lectures.

**Secondary — Class Representative.** A student elevated by a Faculty Rep
(max two per cohort: a primary + an assistant fallback). Has all student
abilities plus: create/manage their cohort (program, semester config),
generate/regenerate a **cohort join code** and remove students from the cohort,
schedule one-time and recurring lectures with automatic venue conflict
detection, and edit/reschedule/cancel lectures.

**Secondary — Faculty Representative.** Manages the academic structure cohorts
operate within. Has all student abilities plus: define programs/courses (and
their number of semesters) and promote students to class rep. At MVP this role
is intentionally minimal — program setup and class-rep promotion are its only
critical functions.

**Infrastructure-only — Superadmin (platform owner).** Not a UI role. Exists
only at the infrastructure level to bootstrap Faculty Reps and seed venue data.

## Current Workarounds

- Verbal negotiation between lecturers and class reps (no central record).
- WhatsApp groups and word of mouth for schedule changes — asynchronous,
  unreliable, easily missed.
- Students discover cancellations and reschedules after the fact.
- Students wander campus looking for a free room with no way to check
  availability.
- Class reps carry the entire coordination burden with no tooling, leading to
  mistakes and gaps.

## Solution Overview

Edutime is an Android-first mobile scheduling platform built specifically for
Chuka University students. It is explicitly **not** a top-down timetabling
system. Instead, class representatives — students elected to coordinate their
cohort — schedule lectures in real time, reflecting the actual agreements made
between students and lecturers. Edutime provides the infrastructure to do that
coordination without conflicts and with instant visibility for every student in
the cohort. It is designed to work under variable connectivity and zero budget.

## Core Value Proposition

A **single trustworthy source of truth** for a cohort's schedule — one that is
conflict-free and updates in real time. "Trustworthy" is the operative word:
the schedule is only valuable if students can trust that the person editing it
is genuinely their legitimately-elected class rep.

### Trust model (the backbone of the product)

Authority flows top-down, and the chain is what makes the schedule trustworthy:

```
Superadmin  →  Faculty Rep  →  Class Rep  →  Student
```

- **Superadmin** bootstraps the first Faculty Reps manually. A Faculty Rep
  registers with an official `@chuka.ac.ke` email; the superadmin verifies them
  out-of-band and promotes them via a privileged script / directly in the
  datastore. No self-service path to Faculty Rep exists. The superadmin role is
  never exposed in the app UI. Acceptable for MVP because there are only ~5–10
  Faculty Reps university-wide.
- **Faculty Rep** is the trust anchor whose authority originates outside the
  app. In the real world they physically run student orientation, call for
  class-rep candidates, run the election on the spot, and personally witness the
  outcome (top two win; a real-world one-male/one-female norm applies). They are
  the only person who can vouch for who legitimately won.
- **Class Rep** promotion is therefore the *only* path to scheduling authority:
  the elected rep creates a normal student account, and the Faculty Rep finds
  and promotes them. **No student can ever self-claim the class rep role.**

**Security property (non-negotiable):** A cohort's schedule can only be created
or modified by someone a Faculty Rep has explicitly promoted. If this guarantee
breaks, the platform's entire trustworthiness collapses.

> Note: the one-male/one-female gender-balance norm is real-world context only.
> It must **not** be hard-enforced by the system at MVP — gating promotions on a
> gender field would be inappropriate.

## Out of Scope

Deliberately excluded from the first build. Not abandoned — phase 2/3. MVP code
must not block adding these later, but they must not be built now.

- **Branch & merge workflows** — subgroups for trimester-track students; merge
  requests; system-suggested merges.
- **Combined (cross-cohort) lectures** — inviting other cohorts; cross-cohort
  conflict detection.
- **Faculty Rep approval workflows** — full approval queues for branch/merge.
- **Formal cohort-join approval workflow** — MVP uses self-service join codes
  with removal as the safety valve; an approval-queue join flow (for
  institutions that want one) is a phase-2 option, not an MVP requirement.
- **Attendance tracking** — not in scope at any near-term phase.
- **Lecturer self-service portal** — lecturers referenced by name only at MVP.
- **Faculty-wide analytics / reporting dashboards.**
- **Smart timetable optimization / AI scheduling suggestions.**
- **Web application** — mobile only for MVP.

## User Journey (First Use)

The MVP is defined by three core journeys. Everything else is deferred until
these three work correctly in the hands of real users.

**Journey 1 — Class rep schedules a lecture (the heart of the system).**
The rep opens the app, creates a lecture event, selects a venue and time, and
the system either confirms the booking or blocks it on conflict. The rep can
edit, reschedule, or cancel afterward. Requires: cohort setup (program, year,
current semester); seeded venue registry; conflict detection (no other cohort
in the same venue at the same time, and no self-overlap); recurring weekly
sessions with pause/edit-series; and an audit trail (every create/edit/cancel
logged with timestamp + acting user).

**Journey 2 — Student sees their schedule.**
A student joins a cohort and immediately sees all upcoming lectures; the
calendar updates in real time as the rep makes changes; push notifications fire
on new/edited/canceled lectures. Requires: cohort join flow (**enter the cohort
join code → immediate access**, no approval/waiting state); calendar views
(day/week/semester);
lecture detail (venue, lecturer name, duration, unit, status); real-time sync
(changes reflected within seconds); push via Firebase Cloud Messaging.

**Journey 3 — Venue availability is visible.**
Any user opens a venue browser and sees which rooms are free now (or at a given
time), removing the "wander campus looking for a room" problem. Requires: venue
list with capacity + type metadata; real-time availability (occupied the moment
a lecture is scheduled); immediate return to available on cancellation.

### Cold start (one real cohort, from empty system)

The hardest period — a student gets zero value until the chain above is in
place. Minimum viable sequence (~2–3 days in real conditions):

1. Superadmin seeds venue data (one-time script from physical campus knowledge).
   Venues are **not** entered by Faculty Reps or class reps.
2. Faculty Rep promoted.
3. Faculty Rep creates program/course data (they own it — it reflects their
   department's real academic structure).
4. Class rep promoted.
5. Class rep creates cohort + semester config; enters unit names as **free-text
   strings** (no formal unit registry at MVP).
6. Class rep schedules the first lectures.
7. Students join via the cohort join code (immediate access — no approval step).

**Requirement:** a student who opens the app before their cohort is fully set up
must see a **clear empty state** explaining what is pending — never a broken or
confusing UI.

## Success Criteria

Measured ~3 months after the first real cohort starts using Edutime.

- **Primary (ground truth, behavioral):** class reps using the system
  voluntarily, without prompting from the platform owner. Cannot be measured in
  the app directly, but it is the real signal.
- **The behavioral shift that defines success:** students checking the app
  instead of asking the class rep on WhatsApp.
- **Quantitative targets:**
  - ≥ 3 active cohorts (a lecture scheduled in the past 14 days).
  - ≥ 60% weekly-active students per cohort.
  - Zero reported venue double-bookings.
- **Instrumentation (data must exist; no dashboard required at MVP):**
  `last_scheduled_at` on cohorts, weekly-active-user counts per cohort, and a
  `conflict_incidents` log (staying empty is the goal).

## Constraints

- **Launch target:** end of September 2026 (target: **Sept 30, 2026**). Chosen
  over an earlier mid-August date as materially more realistic given solo
  development and the genuinely hard pieces (conflict detection, recurring
  series, real-time sync, data-isolation policies, push).
- **Team:** solo (one developer) for now.
- **Budget:** zero institutional budget.
- **Environment:** Android-dominant devices; variable internet connectivity
  (must tolerate intermittent/offline conditions).
- **Scale:** ~20,000 students at Chuka University; ~5–10 Faculty Reps
  university-wide.
- **Legal / privacy — Kenya Data Protection Act 2019 (hard requirements, not
  nice-to-haves):** Edutime is a **data controller** collecting personal data
  (name, email, cohort membership, academic program).
  - A **privacy notice** must be shown at registration, *before* account
    creation, stating what data is collected, why, and that it is not shared
    with third parties.
  - A **data deletion path** must be surfaced in profile/account settings. The
    process may be manual at MVP (user emails the platform owner), but the
    backend must be able to fully delete a user record and all associated
    personal data on request.
  - **Data minimization:** collect only name, email, cohort, role, and
    notification preferences. No phone numbers, no location data, no device
    identifiers beyond what FCM requires for push delivery.
  - Registration must clearly state Edutime is an **independent student
    project, not an official Chuka University system**.
  - Cross-cohort personal-data isolation must be enforced at the data layer — a
    student must never be able to read another cohort's personal data.

## Open Questions

To carry into `/pressure-test` (step 3) — not resolved here.

1. **Faculty Rep email type.** Does an elected *student* Faculty Rep actually
   hold an official `@chuka.ac.ke` address, or only a `@student.chuka.ac.ke`
   one? The superadmin's out-of-band manual verification covers the trust gap
   either way, but the email signal's reliability should be confirmed. (Also a
   latent contradiction to resolve: earlier the Faculty Rep was described as
   "staff or senior student administrator," later as "the elected student rep
   for the faculty" — pin down which.)
2. **Timeline realism — full-time vs. part-time.** Sept 30 has comfortable
   buffer if building full-time, but is "tight but achievable" if working
   around coursework. This single fact decides whether the deadline has margin.
   Validate at pressure-test, with scope kept locked.
