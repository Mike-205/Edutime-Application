---
name: handoff
description: >
  Use this skill when the project (or a milestone) is complete and needs to
  be handed off to a client, another developer, or another agent. Trigger when
  the user says "prepare handoff", "write a handoff doc", "deliver to client",
  "summarize what was built", or "another agent will continue this". Also
  useful at end of a long session to compact context for the next session.
allowed-tools: Read, Bash, Write, Glob
---

# Handoff — Project or Session Delivery Document

You are producing a clear, self-contained handoff document. The recipient may
be a client (non-technical), another developer, or another Claude agent.
Write for the least technical person who might read this.

## Before you start

```bash
git log --oneline -20         # recent commit history
git branch -a                 # branch state
npm run test                  # confirm tests pass
npm run build                 # confirm build passes
```

Read:
- `CLAUDE.md`
- `DISCOVERY.md`
- `MILESTONES.md`

## Ask the user

- Who is this handoff for? (client, developer, another agent)
- Is this a full project handoff or end-of-session handoff?
- Is there anything specific to highlight or flag?

## Output — HANDOFF.md

```markdown
# Handoff Document
**Date:** [today]
**Prepared by:** Claude Code
**Project:** [project name]
**Recipient:** [client / developer / agent]

---

## What Was Built

[2–3 paragraph plain-English summary of the project and what was completed.
No jargon. Write as if explaining to a smart non-technical person.]

## What Is Working

### Features complete and tested
- [feature 1] — [one-line description of what it does]
- [feature 2]
- ...

### How to verify
[Step-by-step instructions to see the working features without reading code]

## What Is Not Done (if applicable)

| Item | Status | Notes |
|---|---|---|
| [feature] | In progress / Not started | [context] |

## How to Run the Project

### Prerequisites
- Node.js [version]
- [any other requirements]

### Setup
\`\`\`bash
git clone [repo-url]
cd [project-name]
npm install
cp .env.example .env
# Fill in the following values in .env:
#   DATABASE_URL — [where to get it]
#   [OTHER_VAR] — [where to get it]
npm run dev
\`\`\`

Open [http://localhost:3000](http://localhost:3000)

### Run tests
\`\`\`bash
npm run test
\`\`\`

## Project Structure (quick map)

\`\`\`
[key folders and what lives in each — 1 line per folder]
\`\`\`

## Key Decisions Made

[3–5 important technical decisions and why they were made — helps the next
person understand the reasoning before changing things]

1. **[Decision]** — [Reason]
2. **[Decision]** — [Reason]

## Known Issues & Gotchas

[Anything the next person needs to know that could trip them up]

- [Issue / Gotcha 1]
- [Issue / Gotcha 2]

## Branch State

| Branch | Status | Notes |
|---|---|---|
| main | [clean / has changes] | |
| dev | [clean / has changes] | |
| feature/XX | [open / merged] | |

## If Another Agent Is Continuing This Work

Current active branch: [branch]
Next milestone: [milestone name and goal from MILESTONES.md]
Start by reading: CLAUDE.md, MILESTONES.md, then run `/code-branch`

---
*This document was generated at the end of a Claude Code session.*
```

After writing HANDOFF.md, tell the user:

"Handoff document is ready at HANDOFF.md. If this is a client delivery,
review it before sending — especially the setup instructions (they should
work on a fresh machine). If continuing in a new session, start by reading
CLAUDE.md and HANDOFF.md to restore context."
