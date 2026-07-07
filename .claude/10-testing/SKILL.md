---
name: testing
description: >
  Use this skill to write and run tests for the current branch. Trigger when
  the user says "write tests", "add tests", "test this", "run the tests",
  or after code review passes on a milestone. Reads ARCHITECTURE.md to use
  the correct testing framework. Tests are written for the current branch's
  code only.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Testing — Write and Run

You are writing and running tests for the current milestone's code. Tests
are not optional and are not written after the project ships. They are written
per milestone, per branch.

## Before you start

```bash
git branch --show-current
npm run test      # confirm the test runner works (even with 0 tests)
```

Read:
- `ARCHITECTURE.md` — testing framework and conventions
- `CLAUDE.md` — any project-specific testing rules
- `MILESTONES.md` — acceptance criteria to base test cases on

## Testing strategy (adapt to the project stack)

### Unit tests
For: pure functions, utility helpers, data transformation logic, validation.

Pattern: test one function, one behavior, one assertion per `it()` block.

```ts
// Good
it('should return null when input is empty string', () => {
  expect(parseUser('').toBe(null)
})

// Bad — tests too many things at once
it('should work', () => {
  expect(parseUser('')).toBe(null)
  expect(parseUser('valid@email.com')).toBeDefined()
  expect(parseUser(null)).toThrow()
})
```

### Integration tests
For: API endpoints, database operations, service layer functions that
combine multiple units.

Test the real behavior through the real interface — not mocked internals.
Use test fixtures or a test database, not production data.

```ts
it('POST /api/users should create a user and return 201', async () => {
  const res = await request(app)
    .post('/api/users')
    .send({ email: 'test@example.com', password: 'secure123' })

  expect(res.status).toBe(201)
  expect(res.body.data.email).toBe('test@example.com')
  expect(res.body.data.password).toBeUndefined() // never return password
})
```

### End-to-end tests (if Playwright/Cypress in stack)
For: critical user flows that must work from browser to database.

Limit these to the 2–3 most important user journeys. E2E tests are slow
and fragile — use them sparingly.

```ts
test('user can sign up and reach dashboard', async ({ page }) => {
  await page.goto('/signup')
  await page.fill('[name=email]', 'test@example.com')
  await page.fill('[name=password]', 'password123')
  await page.click('[type=submit]')
  await expect(page).toHaveURL('/dashboard')
})
```

## What to test on this branch

For each feature/function added in this milestone:

1. **Happy path** — the expected successful flow
2. **Empty / zero / null inputs** — what happens with missing data
3. **Invalid inputs** — what happens with bad data
4. **Auth boundaries** — unauthenticated requests rejected where expected
5. **Error responses** — correct status codes and error shapes returned

## File placement

Co-locate test files next to source files:

```
src/
  services/
    userService.ts
    userService.test.ts    ← here
  routes/
    users.ts
    users.test.ts          ← here
```

Or use a `__tests__` folder if the project convention requires it.

## Running tests

```bash
npm run test              # run all tests
npm run test -- --watch   # watch mode during development
npm run test -- --coverage  # coverage report
```

Coverage target: aim for 70%+ on business logic and API routes.
Don't chase 100% — test meaningful behavior, not getters.

## Output

After writing tests:

```bash
npm run test
```

Report:
```
## Test Results — feature/XX-name

Tests written: [N]
Tests passing: [N]
Tests failing: [N]

Coverage:
  Statements: XX%
  Functions:  XX%
  Lines:      XX%

[List any failing tests and why]
```

All tests must pass before merging. Fix any failures.

When done: "Tests passing. Merge `feature/XX-name` into `dev`:

\`\`\`bash
git checkout dev
git merge feature/XX-name
git push origin dev
\`\`\`

Then run `/code-branch` to start the next milestone."
