# New Project — Claude Code Context

This is a **new project** workspace. No code exists yet.

## Workflow order (follow this sequence)

1. `/discovery-nontechnical` — understand the problem, user, and goals
2. `/discovery-technical` — define stack, architecture, data flow
3. `/pressure-test` — stress-test every decision before touching code
4. `/project-structure` — scaffold folders and template files
5. `/claude-md-generator` — generate the project's CLAUDE.md with full context
6. `/git-setup` — init git, connect GitHub, define branches as milestones (updates CLAUDE.md milestone table)
7. `/code-branch` — work one branch/milestone at a time
8. `/code-review` — review each branch before merging
9. `/testing` — write and run tests per branch
10. `/handoff` — only used if handing off to a client or another agent

## Ground rules

- Never start coding before steps 1–6 are complete
- One branch = one milestone. Never work across two branches simultaneously
- Always run `/code-review` before merging a branch
- Always run `/testing` before closing a milestone
- If you are unsure about a decision, run `/pressure-test` again — it can be called at any point
- Commit messages follow Conventional Commits (see `git-commit` skill)

## What I don't know yet

Everything — this file is a template. The project-specific CLAUDE.md (created by `/claude-md-generator` in step 6) will contain all actual project context.
