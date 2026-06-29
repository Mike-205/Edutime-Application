# Pressure Test Results — Edutime

> Skeptical pre-build review of [DISCOVERY.md](DISCOVERY.md) and
> [ARCHITECTURE.md](ARCHITECTURE.md). 7 issues drilled; all resolved or
> explicitly accepted as risks.

## Resolved Decisions

| Question | Decision | Rationale |
|---|---|---|
| Why would a class rep keep using Edutime when WhatsApp is faster for them? | Their incentive is **liability reduction**, not convenience — Edutime transfers blame to the system (it blocked it, it notified, it has the audit log). | Today the rep *is* the conflict-detection system and takes the blame when it fails. The conflict "no" is protection, not friction. |
| Does the rep-approval join gate survive contact with orientation week? | **No — removed.** Replaced with a **cohort join code**: rep generates/regenerates a code, distributes out-of-band; student enters code → immediate access. Rep can **remove** students (safety valve). | The approval queue contradicts the "instant access" adoption requirement. Removal-not-approval avoids a 60-request bottleneck; wrong-cohort is self-correcting and not an integrity risk. |
| Does a leaked join code expose personal data (DPA)? | **No.** RLS: a student reads **only their own `User` row**; no roster. Class rep reads `user_id, full_name, role` of cohort-mates (no email). Faculty rep reads same for class reps in faculty. **No role reads any other user's `email`.** | A leaked code exposes only schedule data (not personal data under the Act). Contained risk. This RLS design must be implemented + verified before any other policy is considered complete. |
| JWT claim vs `User` table — which is authoritative for RLS role? | **`User` table row.** RLS calls `get_my_role()` (`SELECT role FROM users WHERE id = auth.uid()`); JWT carries identity only. Promotion = live row update, no logout; UI flips via Realtime subscription on the user's own row. | Table-as-truth makes promotion instant and seamless (no stale-JWT "permission denied"). Lookup cost is negligible at this scale. |
| Where does the timeline risk actually sit? | On the **backend** (Supabase/RLS/Postgres/Deno/FCM), not the client. Mitigation: **build backend-first** — conflict constraint + RLS + one real lecture write working end-to-end before polishing any calendar UI. | Developer is solid-intermediate Flutter, lighter on Supabase. The correctness-critical path is also the unfamiliar one; front-loading it de-risks Sept 30. |
| What's the cut order under deadline pressure? | First→last: profile/theme → offline cache → recurring lectures → venue browser → **audit log (defend hard)** → **FCM push (defend to the death)**. Irreducible core: schedule → conflict-block → real-time calendar → push. If any of the four is missing, **delay launch**. | Forces scope discipline and defines what "Edutime" minimally is. |
| Supabase free-tier pause + upgrade trigger? | **Keep-alive:** GitHub Actions cron every 3 days runs a lightweight authenticated query (prevents 7-day pause). **Upgrade to Pro ($25/mo, pre-accepted)** when any holds for 7 consecutive days: DB > 400MB, MAU > 500, or ≥3 cohorts scheduling in one week. Instrumented via a daily `daily_snapshots` table. | Removes the pause credibility-kill; makes the upgrade a hard rule, not a judgment call. `daily_snapshots` doubles as the discovery success-metric instrumentation. |

## Accepted Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Pilot is verbal interest, not a firm named cohort + start date; no confirmed Faculty Rep anchor yet | Medium | High (launches to zero cohorts) | Before heavy build, convert one supporter into "I'll use this with my cohort starting [date]"; confirm a Faculty Rep (possibly the student president) will be the trust anchor. |
| Most-defended feature (FCM push) sits on the weakest skill axis (backend) | Medium | High (core feature slips) | Build the FCM dispatch path early as part of backend-first sequencing; don't leave it to September. |
| Lecture canceled after student already left for venue | Medium | Low–Medium | Notification fires immediately; audit log records cancel time. Real-world limitation, accepted in discovery. |
| Solo developer, single point of failure (bus factor = 1) | Low | High | Open-source MIT repo + documented migrations/architecture lower handoff cost; `/handoff` exists if needed. |
| Join code leaks | Medium | Low | Regeneratable code; schedule-only exposure (no personal data); removal safety valve. |

## Revised Assumptions

- **Cohort join is no longer gated by approval.** It is now self-service via a
  join code, with removal as the safety valve. The `cohort_join_requests` table
  and approval workflow are **removed from MVP scope** (phase-2 option for
  institutions that want it).
- **Role enforcement reads from the `User` table, not the JWT.** JWT is identity
  only.
- **Timeline confidence** is now conditional on **backend-first sequencing**,
  given the developer's Flutter-strong / Supabase-lighter profile.

## Changes to DISCOVERY.md or ARCHITECTURE.md

**DISCOVERY.md** (applied):
1. §User Journey 2 — remove "rep approves"; new flow: enter cohort code →
   immediate access.
2. Class-rep abilities — replace "approve/reject join requests" with "generate/
   regenerate a cohort join code; remove students from the cohort."
3. Cold start step 7 — "students join via cohort code (immediate access)."
4. Out of scope — add: formal join-approval workflow is a phase-2 option.

**ARCHITECTURE.md** (applied):
1. `Cohort` entity — add `join_code` (regeneratable, non-expiring at MVP).
2. API surface — drop `request-join-cohort` / `approve-join` / `reject-join`;
   add `join-cohort-by-code`; keep `remove-student`.
3. RLS — add explicit per-role read matrix for the `User` table; note
   **column-level** enforcement for `email` (view or column GRANTs).
4. Note `get_my_role()` must be **`SECURITY DEFINER` + `STABLE`** to avoid RLS
   recursion.
5. Add `daily_snapshots` table + GitHub Actions keep-alive to infra section.
6. Open questions — mark role-claim + email-exposure resolved; keep recurrence
   horizon + FCM token storage open.

## Verdict

**This plan is ready to build.** It is unusually well-reasoned: the trust chain
is sound, the conflict invariant is enforced at the right layer (the database),
the data model is clean, and scope is disciplined with a clear cut-order. The
pressure test tightened it further — most importantly by removing the
self-defeating approval gate and pinning RLS as the single authoritative access
layer.

The **three things to watch most carefully during the build**:
1. **Secure a firm pilot cohort + a committed Faculty Rep _now_** — before
   sinking weeks into code. The whole launch hinges on a real human anchoring
   the trust chain; verbal enthusiasm is not yet that.
2. **Build backend-first.** Conflict `EXCLUDE` constraint, the full RLS policy
   set (especially the `User`-table read matrix), and the FCM dispatch path are
   your learning cliffs *and* your correctness-critical core. Get them working
   end-to-end before polishing UI.
3. **Verify the RLS read matrix explicitly** (automated tests), because it is
   the technical guarantee behind the DPA commitment — and column-level email
   protection needs a mechanism Postgres RLS doesn't give you for free.