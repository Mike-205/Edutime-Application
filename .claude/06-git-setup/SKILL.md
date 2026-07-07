---
name: git-setup
description: >
  Use this skill to initialize git, connect the project to GitHub, and define
  the branch structure and milestone plan. Trigger when the user says "set up
  git", "connect to GitHub", "initialize git", or "set up version control".
  Should be run after project-structure is complete. Requires the project
  directory to exist and have a working structure.
allowed-tools: Bash, Write, Read
---

# Git & GitHub Setup

You are setting up the version control foundation for this project. By the end,
the project should be on GitHub with a clean initial commit and a clear branch
plan that maps to the project's milestones.

## Before you start

Read `CLAUDE.md`, `ARCHITECTURE.md` and `DISCOVERY.md`. The branch structure
you define must reflect the actual build milestones of this project. Once
MILESTONES.md is written, update the milestone table in `CLAUDE.md`.

## Steps

### 1. Initialize git

```bash
git init
git add .
git commit -m "chore: initial project scaffold"
```

### 2. Create .gitignore (verify it's correct)

Confirm `.gitignore` is already in place from the project-structure step.
If not, create it now. At minimum it must exclude:

- `node_modules/` (or equivalent)
- `.env` (never commit secrets)
- Build output (`dist/`, `.next/`, `build/`, etc.)
- OS files (`.DS_Store`, `Thumbs.db`)
- IDE files (`.vscode/`, `.idea/` — or just the user-specific settings)

### 3. Create the GitHub repository

Ask the user:

- What should the GitHub repo be named?
- Should it be public or private?
- Do you have the GitHub CLI installed? (`gh --version`)

If GitHub CLI is available:

```bash
gh repo create <repo-name> --public/--private --source=. --remote=origin --push
```

If not, instruct the user to:

1. Go to github.com/new
2. Create the repo (no README, no .gitignore — we have those)
3. Copy the remote URL

Then:

```bash
git remote add origin <url>
git branch -M main
git push -u origin main
```

### 4. Define the branch strategy

Ask:

- Will you be the only developer, or are there others?
- Do you have a deployment pipeline that requires a `staging` branch?

**Solo project (recommended):**

```
main          ← production-ready, protected
dev           ← active development base
feature/*     ← one per milestone/feature
```

**Team project:**

```
main          ← production only
staging       ← pre-production testing
dev           ← integration branch
feature/*     ← individual features
hotfix/*      ← production patches
```

Create the branches:

```bash
git checkout -b dev
git push -u origin dev
```

### 5. Define milestones as branches

Read `ARCHITECTURE.md` and `DISCOVERY.md` to identify the natural build phases.
Define 3–6 feature branches that represent real milestones. Example:

```
feature/01-auth          ← user registration and login
feature/02-core-ui       ← main screens and navigation
feature/03-data-layer    ← database models and CRUD
feature/04-api           ← backend API endpoints
feature/05-integrations  ← third-party services
feature/06-polish        ← error handling, loading states, edge cases
```

Adapt these to the actual project. Create them:

```bash
git checkout dev
git checkout -b feature/01-auth
git push -u origin feature/01-auth
# repeat for each
git checkout dev  # return to dev
```

Write the milestone plan to `MILESTONES.md`:

```markdown
# Milestone Plan

Each milestone is a branch. Complete one before starting the next.
All feature branches come off `dev` and merge back into `dev`.
`dev` merges into `main` after testing passes.

## Milestones

### feature/01-auth

**Goal:** [what done looks like]
**Includes:** [what gets built]
**Done when:** [testable acceptance criteria]

### feature/02-core-ui

...
```

### 6. Set up branch protection (optional but recommended)

If using GitHub:

```bash
# Protect main branch via GitHub CLI
gh api repos/:owner/:repo/branches/main/protection \
  --method PUT \
  --field required_pull_request_reviews[required_approving_review_count]=0 \
  --field enforce_admins=false \
  --field restrictions=null \
  --field required_status_checks=null
```

Or instruct the user to do this in GitHub Settings → Branches.

### 7. GitHub Actions (when warranted)

Ask: "Do you want automated CI on every push?" If yes, ask what should run
(lint, tests, build check). Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main, dev]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: "npm"
      - run: npm ci
      - run: npm run lint
      - run: npm run build
      - run: npm test
```

Only add this if the user confirms they want it. Don't add complexity for its
own sake.

## Final check

```bash
git log --oneline
git branch -a
git remote -v
```

Confirm everything is on GitHub. Then update the milestone table in `CLAUDE.md`
with the branches just created.

Tell the user: "Git and GitHub are set up. Branches and milestones are defined
in MILESTONES.md and reflected in CLAUDE.md. Run `/code-branch` to begin
work on the first milestone."
