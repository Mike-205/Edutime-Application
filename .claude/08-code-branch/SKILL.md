---
name: code-branch
description: >
  Use this skill when starting work on a new milestone branch, or when the
  user says "let's start coding", "work on this branch", "build the next
  milestone", "continue the project", or "what do we build next". Reads
  CLAUDE.md and MILESTONES.md to understand the current branch goal.
  Do NOT start coding without confirming which branch we're on.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Code Branch — One Milestone at a Time

You are implementing one milestone. Scope is defined by the current branch.
Nothing outside that scope gets built in this session.

## Before writing a single line

Run these checks:

```bash
git branch --show-current     # confirm we're on the right feature branch
git status                    # confirm working tree is clean
```

Then read:
- `CLAUDE.md` — architecture rules and conventions (mandatory)
- `MILESTONES.md` — what "done" looks like for this branch (mandatory)
- `DISCOVERY.md` — user goals to sanity-check decisions against (if needed)

If we're not on a feature branch, ask the user which milestone to start.
Then:
```bash
git checkout dev
git pull origin dev            # get latest
git checkout feature/XX-name
```

## Coding rules (always apply)

- Follow every rule in `CLAUDE.md` without exception. If a rule conflicts
  with a seemingly better approach, raise it — don't silently override it.
- Write production-quality code, not prototypes. Variable names matter.
  Error handling matters. Edge cases matter.
- Each logical change gets its own commit (see `git-commit` skill).
- Don't install new packages without asking. If a package is needed, state
  why and wait for approval before adding it.
- Never hardcode secrets, URLs, or environment-specific values — use env vars.
- Never modify files outside the current milestone's scope.

## Workflow within the branch

### 1. Orient — understand the milestone goal
State out loud what you're about to build and how it maps to the acceptance
criteria in MILESTONES.md. Wait for confirmation if anything is ambiguous.

### 2. Plan before coding
For any task touching more than 2 files, describe the approach first:
- Which files will be created/modified
- What the data flow looks like
- Any decisions the user should approve before you proceed

### 3. Build incrementally
- Build the smallest working slice first.
- After each logical unit (a working endpoint, a rendered component, a passing
  migration), commit it.
- Run the dev server or test suite after each significant change to catch
  regressions early.

### 4. Check your own work
After completing a section:
```bash
npm run lint      # must pass
npm run build     # must not error
```

Fix any issues before moving on. Don't leave linting errors or broken builds
in the commit history.

### 5. Handle the unexpected
If you discover the milestone requires something that's out of scope or wasn't
in the architecture:
- Stop and surface it: "This requires X which wasn't in the plan. Options are:
  A, B, C. Which do you want?"
- Don't make the decision unilaterally and don't silently expand scope.

## When the milestone is complete

Run the acceptance criteria from MILESTONES.md as a checklist. Tick each one.

```bash
npm run lint
npm run build
npm run test
```

All must pass. Then:

```bash
git add <files>
git commit -m "feat(scope): complete milestone — [brief description]"
git push origin feature/XX-name
```

Tell the user:
"Milestone complete. All acceptance criteria are met.

Next steps:
1. Run `/code-review` to review this branch before merging
2. Run `/testing` to write and run tests
3. After both pass, merge to `dev` and start the next milestone"
