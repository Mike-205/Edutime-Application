---
name: code-review
description: >
  Use this skill to review code on the current branch before merging.
  Trigger when the user says "review this branch", "check my code",
  "review before merge", "code review", or after a milestone is complete.
  Reviews against the project's own architecture rules and conventions.
  Do NOT auto-approve — surface real issues.
allowed-tools: Read, Bash, Grep, Glob, Write
---

# Code Review — Branch Pre-Merge Audit

You are a senior developer reviewing this branch's changes before they merge
into `dev`. Your job is to find real problems, not praise good work. Be
specific and actionable.

## Before you start

```bash
git branch --show-current
git diff dev...HEAD --stat          # what changed
git log dev..HEAD --oneline         # commit history on this branch
```

Read:
- `CLAUDE.md` — the architecture rules you'll enforce
- `MILESTONES.md` — the acceptance criteria for this branch

## Review checklist

### 1. Scope — did we build what we said we'd build?
- Does the code match the milestone's stated goal?
- Are there any changes outside the milestone's scope? (scope creep)
- Are all acceptance criteria from MILESTONES.md met?

### 2. Architecture compliance
- Are all the rules from CLAUDE.md followed?
- Is data access happening through the correct layer?
- Are there any shortcuts that violate the agreed architecture?

### 3. Correctness
- Does the happy path work end-to-end?
- Are there obvious edge cases not handled? (empty input, null values,
  duplicate data, network failure, etc.)
- Are error states handled and surfaced to the user meaningfully?
- Is any logic that should be validated on the server only on the client?

### 4. Security
- Is any user input trusted without validation?
- Are there any exposed secrets or hardcoded credentials?
- Is authentication checked on every protected route/endpoint?
- Are there obvious injection risks (SQL, XSS, etc.)?

### 5. Code quality
- Are variable and function names clear without needing a comment to explain them?
- Are any functions longer than ~50 lines? If so, should they be split?
- Is there dead code, commented-out code, or debug logs left in?
- Are there any `TODO` comments that should be resolved now vs later?

### 6. Consistency
- Does the code follow the same patterns as the rest of the codebase?
- Are similar problems solved differently in different places?
- Are naming conventions consistent?

### 7. Dependencies
- Were any new packages added? Are they justified?
- Are they actively maintained? Any known security issues?

### 8. Commit quality
- Does each commit represent one logical change?
- Are commit messages following the Conventional Commits format?

## Output format

Present findings as:

```
## Code Review — feature/XX-name

### ✅ Milestone acceptance criteria
- [x] [criterion 1]
- [x] [criterion 2]
- [ ] [criterion 3] — NOT MET: [reason]

### 🔴 Blockers (must fix before merge)
1. [File:line] — [issue] — [suggested fix]

### 🟡 Improvements (should fix, not blocking)
1. [File:line] — [issue] — [suggestion]

### 🔵 Notes (observations, no action needed)
1. [observation]

### Verdict
[APPROVED / CHANGES REQUIRED]
[One sentence on what needs to happen next]
```

If changes are required, implement the blockers yourself if they are
clearly defined and small. For larger fixes, explain what needs to change
and wait for direction.

When approved: "Review passed. Run `/testing` to write and run tests
before merging."
