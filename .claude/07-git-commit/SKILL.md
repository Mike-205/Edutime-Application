---
name: git-commit
description: >
  Use this skill whenever committing code, staging changes, writing a commit
  message, or when the user says "commit this", "make a commit", "what should
  the commit message be", or "stage and commit". Applies to every commit
  throughout the project lifecycle. Do NOT use for PR descriptions or
  changelogs — those are separate.
allowed-tools: Bash
---

# Git Commit — Conventional Commits

Every commit in this project follows the Conventional Commits specification.

## Format

```
<type>(<scope>): <short summary>

[optional body]

[optional footer]
```

## Types

| Type | When to use |
|---|---|
| `feat` | A new feature or user-visible capability |
| `fix` | A bug fix |
| `chore` | Build process, tooling, dependency updates — no production code |
| `refactor` | Code restructuring with no behavior change |
| `style` | Formatting, whitespace, missing semicolons — no logic change |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `perf` | Performance improvement |
| `ci` | CI/CD configuration changes |
| `revert` | Reverting a previous commit |

## Scope (optional but encouraged)

The scope is the area of the codebase affected. Use the folder name or
feature name. Examples: `auth`, `api`, `ui`, `db`, `config`.

```
feat(auth): add email verification flow
fix(api): handle null user in profile endpoint
chore(deps): upgrade next.js to 15.2
```

## Summary rules

- Use the imperative mood: "add feature" not "added feature" or "adds feature"
- Keep under 70 characters
- No period at the end
- Lowercase everything after the colon (except proper nouns)

## Body (when to add one)

Add a body when:
- The change touches more than 3 files
- The reasoning isn't obvious from the summary
- You're making a tradeoff someone should know about

Wrap body at 72 characters. Blank line between summary and body.

## Footer

Use for breaking changes or issue references:
```
BREAKING CHANGE: removed /api/v1/users endpoint
Closes #42
```

## Before committing — always check

```bash
git status          # see what's changed
git diff --staged   # review what's staged
```

Only stage what belongs in this commit. Don't bundle unrelated changes.

```bash
git add <specific files>    # preferred over git add .
git commit -m "type(scope): summary"
```

## Examples

```bash
# Good
git commit -m "feat(auth): add JWT refresh token rotation"
git commit -m "fix(db): prevent duplicate email on signup"
git commit -m "chore: add prettier config"
git commit -m "test(api): add coverage for error response shapes"

# Bad — too vague
git commit -m "fix stuff"
git commit -m "updates"
git commit -m "WIP"

# Bad — wrong tense
git commit -m "added login page"
git commit -m "fixes the bug"
```

## Atomic commits

Each commit should do **one thing**. If you find yourself writing "and" in a
commit message, split it into two commits.
