---
name: project-structure
description: >
  Use this skill to scaffold the initial project structure and template files
  after the architecture is designed and pressure-tested. Trigger when the user
  says "scaffold the project", "create the project structure", "set up the
  folders", or "let's start the project setup". Requires ARCHITECTURE.md to
  exist. Do NOT start writing real application logic — only structure and
  template files.
allowed-tools: Read, Write, Bash
---

# Project Structure — Scaffold & Verify

You are setting up the skeleton of the project. The goal is a running,
verifiable starting point — not a line of application logic, just the right
structure for the stack and a confirmed working baseline.

## Before you start

Read `ARCHITECTURE.md` fully. Every folder and file you create must reflect
the chosen stack. Do not deviate from the documented architecture.

## Rules

- Create real files, not descriptions of files.
- Every template file should have the minimum content needed to be valid
  (imports, boilerplate, placeholder comments) — not lorem ipsum, not TODO soup.
- After scaffolding, run the install and start commands and confirm the project
  boots without errors. If it doesn't, fix it before telling the user it's done.
- Do not install packages that aren't in ARCHITECTURE.md without asking first.
- Never create files in the wrong layer (e.g. database logic in the frontend folder).

## What to create

### 1. Root-level files

- `package.json` (or equivalent for the chosen stack) with correct scripts:
  `dev`, `build`, `test`, `lint`
- `.env.example` with every required environment variable (values as
  descriptive placeholders, never real values)
- `.gitignore` appropriate for the stack (node_modules, .env, build output,
  OS files, IDE files)
- `README.md` with: project name, one-line description, setup instructions,
  and how to run the project
- Config files for linting/formatting if in the architecture (eslint, prettier,
  biome, etc.)
- TypeScript config if applicable

### 2. Source structure

Create folders that match the architecture. Common patterns:

**Full-stack web (e.g. Next.js):**

```
src/
  app/          # routes/pages
  components/   # shared UI components
  lib/          # utilities and helpers
  server/       # server-only code
  types/        # shared TypeScript types
```

**Separate frontend + backend:**

```
apps/
  web/          # frontend
  api/          # backend
packages/
  types/        # shared types (if monorepo)
```

**Backend API:**

```
src/
  routes/       # endpoint handlers
  services/     # business logic
  models/       # data models
  middleware/   # request middleware
  lib/          # utilities
```

Adapt to what ARCHITECTURE.md actually specifies.

### 3. Template files (per layer)

Each key folder should have at least one template file showing the correct
pattern for that layer. Examples:

- A sample route/page with correct imports
- A sample component with the right structure
- A sample service/util function
- A sample type/interface file
- A database config file (with env var references, not hardcoded values)

### 4. Verify it runs

```bash
# Install dependencies
npm install   # or pnpm/yarn/bun per architecture

# Start the dev server
npm run dev

# Run the test suite (even if empty, confirm it runs)
npm run test

# Run lint (confirm it passes)
npm run lint
```

Fix any errors before declaring this step done.

## Output

After scaffolding, print a file tree of everything created:

```
my-project/
├── package.json
├── .env.example
├── .gitignore
├── README.md
├── tsconfig.json
└── src/
    ├── app/
    │   └── page.tsx         # template
    ├── components/
    │   └── Button.tsx       # template
    └── lib/
        └── utils.ts         # template
```

Then confirm: "Project runs clean. Run `/claude-md-generator` to generate
the project's CLAUDE.md while we have full context — then we'll set up git."
