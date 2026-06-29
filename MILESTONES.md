# Milestone Plan — Edutime

Each milestone is a branch. Complete one before starting the next.
All feature branches come off `dev` and merge back into `dev`.
`dev` merges into `main` after `/testing` passes.

**Branch model (solo):**

```
main                              ← production-ready, protected
dev                               ← active development base
feature/01-auth-rls               ← auth + RLS foundation (the DPA guarantee)
feature/02-cohorts                ← cohort lifecycle + self-service join
feature/03-scheduling             ← conflict-free lecture scheduling (the core invariant)
feature/04-calendar-realtime      ← calendar views + live realtime updates
feature/05-notifications          ← FCM push dispatch + in-app history
feature/06-instrumentation-polish ← snapshots, keep-alive, offline, DPA deletion, polish
```

**Build order is backend-first** (per PRESSURE-TEST.md): the conflict constraint,
RLS, and FCM dispatch are proven before UI is polished. The dev is Flutter-strong
and Supabase-lighter, so the risky backend integrations come first.

Workflow per milestone: `/code-branch` to start → build → `/code-review` before
merging → `/testing` before closing. One branch at a time; never two at once.

---

## Milestones

### feature/01-auth-rls

**Goal:** A user can register and log in; the database enforces who can read what,
and no user can ever read another user's `email`.

**Includes:**
- Supabase Auth email/password wiring (client + `AuthBloc`); session restore.
- Registration flow surfacing the DPA privacy notice + "independent student
  project, not official Chuka" disclaimer (Kenya DPA 2019 requirement).
- `get_my_role()` (`SECURITY DEFINER` + `STABLE`) as the sole role authority;
  no client-side or JWT-claim role checks.
- The `users` read matrix from ARCHITECTURE.md enforced and tested: student reads
  own row only; cohort-mate lists come through `get_cohort_members()` (name + role,
  **never** email).
- Live role flip via a Realtime subscription on the user's own row (no logout on
  promotion).

**Done when:** A student account cannot read any other user's `email` (verified by
test against RLS), login/logout/session-restore work, and role is read only via
`get_my_role()`.

---

### feature/02-cohorts

**Goal:** Faculty/program/cohort structure exists; a student can join a cohort by
code instantly, and a class rep can manage membership.

**Includes:**
- Faculty / Program / Cohort models + read access under RLS.
- `join-cohort-by-code` Edge Function — valid code → immediate membership, **no
  approval queue**.
- Class-rep-gated `remove-student` and `regenerate-join-code`.
- `promote-class-rep` (Faculty-Rep-only — the sole path to class-rep authority).
- Cohort member list UI showing `full_name` + `role` only (no roster of emails).

**Done when:** A student joins via code and immediately sees their cohort; a class
rep can remove a member and regenerate the code; a leaked code exposes schedule
data only, never personal data.

---

### feature/03-scheduling

**Goal:** A class rep schedules conflict-free lectures; double-booking is
physically impossible. This is the project's core invariant.

**Includes:**
- `schedule-lecture` Edge Function: Flutter pre-check → Edge pre-check (readable
  error) → insert under DB enforcement. Writes the `lecture_audit_log` row.
- `edit-lecture` and `cancel-lecture` (cancel frees the venue immediately).
- Recurring series = **one row per occurrence** sharing `recurrence_group_id`;
  each occurrence conflict-checked individually.
- Exercises the `0002` `EXCLUDE` constraints (`lectures_no_venue_overlap`,
  `lectures_no_cohort_overlap`) as ground truth — Edge/Flutter checks are UX only.
- Postgres-level tests proving two racing inserts cannot double-book a venue.

**Done when:** No overlapping venue or cohort booking can be persisted (proven by a
concurrent-insert DB test), audit log records every create/edit/cancel, and
recurring series check each occurrence independently.

---

### feature/04-calendar-realtime

**Goal:** Students see their cohort's schedule and venue availability update live,
within seconds of a rep's change.

**Includes:**
- `table_calendar`-based day / week / semester views.
- Supabase Realtime subscriptions driving the calendar and venue-availability flips.
- Offline tolerance: cached schedule readable offline; clear feedback when a write
  needs connectivity.
- Reads go directly through the client under RLS (no custom endpoints).

**Done when:** A rep's schedule/edit/cancel reflects on a subscribed student's
calendar within seconds, venues flip available/occupied live, and the cached
schedule renders offline.

---

### feature/05-notifications

**Goal:** Lecture changes push to affected students and are recorded for in-app
history.

**Includes:**
- DB Database Webhook → `dispatch-fcm` Edge Function (secured by
  `FCM_WEBHOOK_SECRET`), sending new/updated/canceled push via FCM.
- `notifications` rows written for in-app history (read/unread).
- Per-user FCM device-token storage + refresh.
- Resolve the open question: Database Webhook vs `pg_net` (ARCHITECTURE.md §Open
  Questions) — confirm and document the chosen path.

**Done when:** Scheduling/editing/canceling a lecture delivers an FCM push to
cohort students and writes a matching `notifications` row; tokens refresh correctly.

---

### feature/06-instrumentation-polish

**Goal:** The success-metric / upgrade-trigger instrumentation runs, free-tier
keep-alive holds, and the DPA + UX edges are handled.

**Includes:**
- `daily-snapshot` Edge Function populating `daily_snapshots` (MAU, active cohort
  count, DB-size estimate) once/day.
- Verify `keepalive.yml` cron prevents the 7-day free-tier pause and logs the latest
  snapshot.
- `request-account-deletion` — surfaced DPA deletion path (manual fulfilment at MVP).
- Offline/error/loading-state polish across flows; graceful degradation.

**Done when:** `daily_snapshots` accrues a row per day, keep-alive is confirmed
working, the account-deletion path is reachable from the UI, and core flows handle
offline/error states cleanly.

---

## Notes

- The schema migrations (`0001` schema, `0002` conflict constraints, `0003` RLS)
  and Edge Function skeletons already exist from project-structure; milestones wire
  them up and prove them, they do not redefine the schema by hand.
- Never change the schema by hand — add a numbered migration in
  `supabase/migrations/`.
- Phase-2 scope (branch/merge, combined lectures, faculty approval queues, unit
  registry, lecturer accounts, web app) stays **out** of these milestones.
