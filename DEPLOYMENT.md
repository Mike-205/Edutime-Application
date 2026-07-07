# Deployment Guide — Edutime

How to run Edutime locally and deploy it to hosted Supabase + Google Play. Work
through it in order: **A→B first (local), then C onward (hosted)**. Placeholders
are in `<angle brackets>`.

Toolchain: Flutter via **FVM** (3.41.2), **Supabase CLI** + **Docker**, Deno
(bundled with the Supabase CLI for Edge Functions).

---

## A. One-time tooling

You need FVM Flutter 3.41.2 + Docker Desktop. Add the Supabase CLI:

```bash
# Windows (scoop) — or download the release binary from github.com/supabase/cli
scoop install supabase
supabase --version
```

---

## B. Run the whole thing locally

**1. Start the local stack** (Docker Desktop must be running):

```bash
supabase start          # first run pulls images; takes a few min
supabase status         # prints API URL + anon key + service_role key — copy these
```

`supabase start` gives you `API URL: http://127.0.0.1:54321` and a local `anon key`.

**2. Apply schema + seed:**

```bash
supabase db reset       # runs all migrations/ + seed.sql into the local DB
```

**3. Edge Function env for local serving** — create `supabase/functions/.env`
(gitignored):

```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_SERVICE_ROLE_KEY=<service_role key from `supabase status`>
FCM_SERVICE_ACCOUNT=<paste service-account JSON once you have Firebase — see E>
FCM_WEBHOOK_SECRET=<any long random string>
```

Then serve:

```bash
supabase functions serve --env-file supabase/functions/.env
```

**4. Run the app against local Supabase.** The host address differs by target:

- **Android emulator:** the host machine is reachable at `10.0.2.2`
  ```bash
  fvm flutter run \
    --dart-define=SUPABASE_URL=http://10.0.2.2:54321 \
    --dart-define=SUPABASE_ANON_KEY=<local anon key>
  ```
- **Physical Android device (USB):** forward the port first, then use localhost:
  ```bash
  adb reverse tcp:54321 tcp:54321
  fvm flutter run \
    --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
    --dart-define=SUPABASE_ANON_KEY=<local anon key>
  ```

The debug manifest already allows cleartext HTTP for exactly this. Register a
user and you're running locally end-to-end (push won't work until Firebase — E).

---

## C. Create the hosted Supabase project

1. **app.supabase.com → New project.** Choose the region **closest to Kenya**
   (e.g. an EU region), set a **database password** (save it).
2. From **Project Settings → API**, copy: **Project URL**, **anon public key**,
   **service_role key**.
3. Note your **project ref** (the `xxxx` in `https://xxxx.supabase.co`).

---

## D. Deploy schema + Edge Functions to the hosted project

```bash
supabase login                       # opens browser / paste access token
supabase link --project-ref <ref>    # prompts for the DB password from step C
supabase db push                     # applies supabase/migrations/ to the remote DB
```

**Seed the reference data.** ⚠️ Replace `seed.sql` with **real Chuka data**
first — faculties→departments→programs→courses and buildings→rooms→venues; a rep
can schedule nothing until these exist. `db push` does **not** run the seed, so
run it explicitly:

```bash
psql "postgresql://postgres:<DB-PASSWORD>@db.<ref>.supabase.co:5432/postgres" \
  -f supabase/seed.sql
```

(Or paste `seed.sql` into the Dashboard **SQL Editor**.)

**Set Edge Function secrets.** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` are **auto-injected** into deployed functions — do
**not** set those. Only the third-party ones:

```bash
supabase secrets set \
  FCM_PROJECT_ID=<firebase-project-id> \
  FCM_WEBHOOK_SECRET=<long random string> \
  RESEND_API_KEY=<resend key> \
  FCM_SERVICE_ACCOUNT="$(cat <path-to-service-account>.json)"
```

**Deploy the functions:**

```bash
supabase functions deploy      # deploys all; or `deploy schedule-lecture` etc.
# fcm-poc is a throwaway — delete the folder or skip it.
```

Functions default to requiring a JWT. The app's `functions.invoke` sends the
user's token automatically, so `schedule`/`edit`/`cancel-lecture` and
`request-account-deletion` work as-is.

---

## E. Firebase / FCM (push notifications)

1. **console.firebase.google.com → Add project.**
2. **Add an Android app** with package name **`ke.ac.chuka.edutime`** (the
   `applicationId`). Download **`google-services.json`** → put it in
   **`android/app/google-services.json`** (gitignored — never commit).
3. **Add the Google Services Gradle plugin** (Kotlin DSL, this project):
   - `android/settings.gradle.kts`, in the `plugins { }` block:
     `id("com.google.gms.google-services") version "4.4.2" apply false`
   - `android/app/build.gradle.kts`, in its `plugins { }` block:
     `id("com.google.gms.google-services")`
   - *Shortcut:* `dart pub global activate flutterfire_cli` then
     `flutterfire configure` wires most of this for you.
4. **Service account** (so the server can send pushes): Firebase
   **Project settings → Service accounts → Generate new private key**. The JSON
   is your **`FCM_SERVICE_ACCOUNT`** secret (step D).
5. Confirm delivery with `fcm-poc` (see its header comment) or by scheduling a
   lecture and watching a second device.

> `.env.example` still lists the old `FCM_SERVER_KEY` — ignore it. The code uses
> **FCM HTTP v1** with `FCM_SERVICE_ACCOUNT` (the legacy server-key API is dead).

---

## F. Point the app at production & build

```bash
# Run against prod:
fvm flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<prod anon key>

# Release build for Play:
fvm flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<prod anon key>
```

Tip: put the two defines in a JSON file and use
`--dart-define-from-file=prod.json` so you don't retype them (keep it gitignored).

---

## G. Schedule the daily snapshot

Simplest path — `pg_cron` calls the SQL function directly (no need to invoke the
Edge Function). In the Dashboard **SQL Editor**:

```sql
create extension if not exists pg_cron;
select cron.schedule('daily-snapshot', '0 1 * * *', $$select record_daily_snapshot()$$);
```

That writes one `daily_snapshots` row per day. The `daily-snapshot` Edge Function
is just an HTTP wrapper around the same function if you ever want to trigger it
over HTTP instead.

---

## H. Bootstrap the trust chain (one-time — the discovery cold-start)

1. Seed reference data (section D) — you, as owner, via service role.
2. A **Faculty Rep** registers a normal account in the app; you promote them in
   the **SQL Editor**:
   ```sql
   update users set role = 'faculty_rep' where email = '<their email>';
   ```
   (Superadmin stays infra-only — never a UI role.)
3. From there it's in-app: the Faculty Rep defines programs/courses and promotes
   a **class rep**; the class rep creates the cohort + join code and schedules
   lectures; students join by code.

---

## I. GitHub Actions secrets (keep-alive + CI)

Repo → **Settings → Secrets and variables → Actions** → add:

- `SUPABASE_URL`, `SUPABASE_ANON_KEY` — used by `keepalive.yml` (reads
  `daily_snapshots`, which is anon-readable).
- If CI should auto-deploy functions/migrations, also add `SUPABASE_ACCESS_TOKEN`
  + the project ref, and check what `ci.yml` expects.

---

## J. Google Play (distribution)

1. Pay the one-time **$25** for a Play Console account.
2. Create the app → set up a **closed testing** track first.
3. Add a proper **release signing key** (the build currently signs with debug
   keys — see the `TODO` in `android/app/build.gradle.kts`).
4. Upload the `.aab` from section F → roll out to testers → then production.

---

## The order that matters

**B** (prove it locally) → **C/D** (schema + functions live) → **E** (push) →
**H** (bootstrap one real cohort) → **F/J** (ship). Sections **G** and **I** can
happen any time after D.

The one thing no guide can do for you (and the pressure test's #1 risk): **line
up a real pilot cohort + a committed Faculty Rep** before investing in the Play
release + onboarding.
