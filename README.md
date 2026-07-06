# Edutime

Student-driven lecture scheduling for Chuka University. Class representatives
schedule conflict-free lectures to venues; students see their cohort's schedule
in real time and get push notifications on changes. Android-first (Flutter),
backed by Supabase. Open source (MIT) so other universities can self-deploy.

See [DISCOVERY.md](DISCOVERY.md), [ARCHITECTURE.md](ARCHITECTURE.md), and
[PRESSURE-TEST.md](PRESSURE-TEST.md) for the full design and the decisions
behind it.

## Stack

| Layer | Tech |
|---|---|
| Client | Flutter (Dart), BLoC, `table_calendar` |
| Backend | Supabase (Postgres + Auth + Realtime + Edge Functions + Storage) |
| Push | Firebase Cloud Messaging |
| Email | Resend |
| CI/CD | GitHub Actions + Supabase CLI |

## Repository layout

```
lib/                      Flutter app (feature-first)
  core/                   config, theme, router, supabase client
  data/                   models + repositories
  features/               auth, cohort, calendar, venues (bloc + screens)
test/                     widget/unit tests
supabase/
  migrations/             schema, conflict constraints, RLS
  functions/              Edge Functions (Deno/TypeScript)
  seed.sql                venue registry seed (replace with real data)
  config.toml             local Supabase config
.github/workflows/        ci.yml, keepalive.yml
```

## Prerequisites

- **Flutter** 3.41.x (this repo uses [FVM](https://fvm.app): `fvm use 3.41.2`).
- **Supabase CLI** — https://supabase.com/docs/guides/cli
- **Docker** — required by `supabase start` for the local stack
- **Deno** — Edge Functions runtime (bundled with the Supabase CLI).

## Setup

```bash
# 1. Client deps
fvm flutter pub get

# 2. Environment
cp .env.example .env        # fill in real values (never commit .env)

# 3. Backend (after installing Supabase CLI + Docker)
supabase start              # boots local Postgres + Auth + Studio
supabase db reset           # applies migrations/ + seed.sql
```

## Run

```bash
fvm flutter run             # launch the app on a connected device/emulator
fvm flutter analyze         # static analysis
fvm flutter test            # test suite
```

## Status

Scaffold stage (step 4 of the project workflow). No application logic yet —
structure, schema, RLS, and Edge Function skeletons only. Build proceeds one
milestone per branch via `/code-branch`.

## License

MIT.