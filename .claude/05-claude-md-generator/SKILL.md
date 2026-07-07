---
name: claude-md-generator
description: >
  Use this skill to generate the project's own CLAUDE.md file after the
  project structure and git setup are complete. Trigger when the user says
  "create the CLAUDE.md", "generate claude context", or "set up claude for
  this project". Requires DISCOVERY.md, ARCHITECTURE.md, MILESTONES.md to
  exist. This generates the project CLAUDE.md — not the workflow one.
allowed-tools: Read, Write, Bash
---

# CLAUDE.md Generator

You are generating the project's own `CLAUDE.md` — the file that will be loaded
into every future Claude Code session for this specific project. This runs after
project-structure so you have full context: the problem, the architecture, and
the actual scaffolded codebase. Git and GitHub come next.

## Before you start

Read all of the following in full:

- `DISCOVERY.md`
- `ARCHITECTURE.md`
- `PRESSURE-TEST.md`
- `package.json` (or equivalent)

Also run:

```bash
ls -la          # verify project structure
cat .env.example  # note required env vars
```

## Rules for a good CLAUDE.md

- **Under 200 lines.** Every line is loaded into every session. Be ruthless.
- **Document decisions, not aspirations.** "We use Prisma" not "We follow
  database best practices."
- **Document the non-obvious.** Don't write "write clean code". Write
  "all database queries go through the service layer — never query from routes."
- **Include the commands Claude will need to run** (dev, test, lint, build).
- **Reference the milestone plan** so Claude knows what branch it's on and
  what done looks like.

## Output — CLAUDE.md (project root)

Generate the file at the project root as `CLAUDE.md`:

```markdown
# [Project Name] — Claude Code Context

## What This Project Is

[One paragraph from DISCOVERY.md — problem, solution, primary user]

## Current Status

- Active branch: [to be updated each session]
- Current milestone: [to be updated each session]
- Milestone goal: [to be updated each session]

## Commands

\`\`\`bash
npm run dev # start dev server ([port])
npm run build # production build
npm run test # run test suite ([framework])
npm run lint # lint and format check
\`\`\`

## Tech Stack

| Layer    | Choice | Notes |
| -------- | ------ | ----- |
| Frontend | ...    | ...   |
| Backend  | ...    | ...   |
| Database | ...    | ...   |
| Auth     | ...    | ...   |
| Hosting  | ...    | ...   |

## Project Structure

\`\`\`
src/
[key folders and what lives in each — 1 line per folder]
\`\`\`

## Architecture Rules (non-negotiable)

- [rule 1 from ARCHITECTURE.md — e.g. "All DB access goes through /server/db, never directly from components"]
- [rule 2]
- [rule 3]
- [Add only rules Claude is likely to violate without being told]

## Coding Conventions

- [e.g. "TypeScript strict mode — no implicit any"]
- [e.g. "Functional components only — no class components"]
- [e.g. "All API responses follow { success, data, error } shape"]
- [3–6 conventions that are project-specific and non-obvious]

## Environment Variables

All secrets live in `.env`. Never hardcode. See `.env.example` for required vars:

- `DATABASE_URL` — [what it's for]
- `[VAR_NAME]` — [what it's for]

## Milestone Plan

_(To be populated after `/git-setup` defines the branches)_

Branches will be defined as milestones in `MILESTONES.md`. Update this
section after running `/git-setup`.

## Key Decisions (from ARCHITECTURE.md)

- [Decision 1 and why — e.g. "Using Supabase Auth over custom auth: faster to ship, acceptable vendor dependency at this scale"]
- [Decision 2]
- [3–5 decisions Claude should know about to avoid re-litigating them]

## Known Constraints

- [e.g. "No external API calls from the frontend — route through backend"]
- [e.g. "Must work on mobile browsers — test at 375px width"]
- [From PRESSURE-TEST.md accepted risks or constraints]

## What Claude Should NOT Do

- Never modify the database schema directly — always through migrations
- Never commit `.env` files
- Never write application logic in route files — use service layer
- [Add 2–3 project-specific prohibitions]
```

After writing the file, tell the user:

"CLAUDE.md is ready at the project root. This file will be loaded into every
future session. Update the `Current Status` section at the start of each work
session to tell me which branch and milestone we're on.

Now run `/git-setup` to initialize git, connect to GitHub, and define
your milestone branches."
