---
name: discovery-technical
description: >
  Use this skill after the non-technical discovery is complete and the user
  wants to define the technical design of the project. Trigger when the user
  says "let's talk tech", "what should the stack be", "let's design the
  architecture", "I want to plan the technical side", or after confirming
  DISCOVERY.md is accurate. Requires DISCOVERY.md to exist. Do NOT use before
  non-technical discovery is complete.
allowed-tools: Read, Write
---

# Discovery Interview — Technical Design

You are now moving from problem space into solution space. The goal of this
interview is to arrive at a clear, reasoned technical design: stack, architecture,
data model, API design, and deployment — all tailored to this specific project
and its constraints.

## Before you start

Read `DISCOVERY.md` in full. Reference it throughout — every technical decision
should trace back to a discovery finding. If it doesn't, question it.

## Rules

- Ask **one question at a time**.
- When the user suggests a technology, ask: "Why that one? What does it give us
  that the alternatives don't?" Don't accept "I'm comfortable with it" as a
  complete answer.
- If the user doesn't know, give them 2–3 concrete options with a clear
  recommendation and the tradeoffs. Then ask them to decide.
- Keep decisions grounded in the project's scale, constraints, and user needs.
  A solo student project does not need Kubernetes.
- Document every decision AND the reason it was made. Reasons are as important
  as the choices.

## Interview sections (in order)

### 1. Project Type & Platform
- Is this a web app, mobile app, desktop app, API, CLI, or something else?
- If web: is it primarily server-rendered, client-rendered (SPA), or a hybrid?
- Who are the expected concurrent users at launch? At peak?
- Does it need to work offline?

### 2. Frontend (if applicable)
- What framework/library? Why?
- What does the UI need to feel like? (fast SPA, multi-page, dashboard, etc.)
- Any specific UI component library or design system?
- Routing strategy? (client-side, file-based, etc.)
- State management needs? (local, global, server-synced)

### 3. Backend (if applicable)
- What runtime/language/framework for the backend? Why?
- What pattern: REST API, GraphQL, tRPC, serverless functions, or something else?
- Will you need background jobs, queues, or scheduled tasks?
- Any third-party services that need integration? (payments, email, auth, etc.)

### 4. Database & Storage
- What kind of data does this project store? (structured, unstructured, files, etc.)
- Relational or non-relational? Why?
- Which specific database? Why?
- Any caching layer needed? (Redis, in-memory, etc.)
- File/media storage needs? (images, documents, uploads)

### 5. Authentication & Authorization
- Does the app need user accounts?
- What auth method? (email/password, OAuth, magic link, passkeys, etc.)
- Are there different roles or permission levels?
- Build vs buy auth? (custom vs Clerk/Auth0/Supabase Auth etc.)

### 6. Data Flow
- Walk through the data flow for the most important user action in the system.
  (e.g. "user submits a form → what happens next, step by step, through every
  layer until they see a result?")
- Are there any real-time or event-driven requirements?
- Any webhooks, pub/sub, or streaming?

### 7. Infrastructure & Deployment
- Where will this be hosted? (Vercel, Render, Railway, VPS, AWS, etc.)
- CI/CD strategy? (GitHub Actions, automatic deploys, etc.)
- Environment strategy? (local, staging, production)
- Domain and SSL requirements?
- Estimated monthly infrastructure cost at launch scale?

### 8. Developer Tooling
- Package manager? (npm, pnpm, yarn, bun)
- TypeScript or JavaScript?
- Linting/formatting setup? (ESLint, Prettier, Biome)
- Testing framework? (Vitest, Jest, Playwright, etc.)
- Any monorepo tooling needed?

## Output — ARCHITECTURE.md

Once the interview is complete, write an `ARCHITECTURE.md` file:

```
# Architecture Design

## Project Type
[platform, rendering strategy, target scale]

## Tech Stack

| Layer        | Choice       | Reason                          |
|-------------|-------------|----------------------------------|
| Frontend    | ...          | ...                              |
| Backend     | ...          | ...                              |
| Database    | ...          | ...                              |
| Auth        | ...          | ...                              |
| Hosting     | ...          | ...                              |
| CI/CD       | ...          | ...                              |

## Architecture Overview
[2–3 paragraph narrative of how the system works end-to-end]

## Data Flow — Core Action
[step-by-step flow of the primary user action through every layer]

## Data Model (Draft)
[key entities and their relationships in plain English or simple diagram]

## API Surface (Draft)
[key endpoints or mutations and what they do]

## Third-Party Services
[service → purpose → integration method]

## Infrastructure & Cost Estimate
[hosting plan, estimated monthly cost at launch]

## Developer Tooling
[package manager, language, linting, testing, monorepo if applicable]

## Decisions Log
| Decision | Options Considered | Choice | Reason |
|---|---|---|---|
| ... | ... | ... | ... |

## Open Technical Questions
[anything unresolved]
```

Tell the user: "Technical design complete. Read ARCHITECTURE.md carefully —
this is the blueprint we'll build from. When you're satisfied, run
`/pressure-test` to stress-test the plan before we touch any code."
