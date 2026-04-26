# prisma-db

A skill for database optimization, schema design, and query performance work in projects using Prisma ORM with PostgreSQL.

## Trigger conditions

Use this skill when the user asks about any of the following in a Prisma + PostgreSQL project:

- Schema changes, model additions, or field modifications
- Adding or reviewing indexes
- Query performance, slow queries, or N+1 problems
- Migration authoring or reviewing migration files
- PrismaClient configuration (singleton, connection pooling)
- `EXPLAIN ANALYZE` or query plan interpretation
- Prisma `select`, `include`, `findMany`, `createMany`, `upsert` usage
- Database constraints (unique, FK, check)
- Optimizing `addCandidate` or similar bulk-insert patterns
- Connection pooling (PgBouncer, Prisma Accelerate)

## Instructions

When invoked, follow this structured workflow:

### 1. Understand the current state

Before suggesting any change, read:
- `backend/prisma/schema.prisma` — the single source of truth
- The relevant domain model file(s) in `backend/src/domain/models/`
- The relevant service file(s) in `backend/src/application/services/`
- Any existing migration files in `backend/prisma/migrations/` that relate to the change

Never propose a migration without reading the current schema first.

### 2. Identify the problem class

Classify the issue into one or more of these categories before proposing a solution:

| Problem class              | Typical fix                                              |
|----------------------------|----------------------------------------------------------|
| N+1 queries                | Use Prisma `include` or batch with `createMany`          |
| Missing index              | Add `@@index` in schema + migrate                        |
| PrismaClient proliferation | Refactor to shared singleton in `lib/prisma.ts`          |
| Over-fetching              | Add `select` to limit returned columns                   |
| Missing FK cascade         | Add `onDelete`/`onUpdate` to `@relation`                 |
| Slow full-table scan       | Add index, rewrite query, or add pagination              |
| Large payload              | Paginate with `skip`/`take`, add cursor-based pagination |

### 3. Schema changes

When modifying `schema.prisma`:

- Always add `@@index([candidateId])` on any model that has a `candidateId` FK (or any high-cardinality FK used in WHERE clauses).
- **`onDelete` trade-off — choose deliberately:**
  - The schema uses `onDelete: Restrict` on `Education`, `WorkExperience`, and `Resume` → `Candidate`. This is intentional: it prevents silent data loss and forces callers to explicitly delete child records before removing a candidate.
  - Use `onDelete: Cascade` only when child rows are meaningless without the parent and silent removal is safe (e.g., `InterviewStep` → `InterviewFlow`, `Interview` → `Application`).
  - Do not change existing `Restrict` rules without a documented reason — they represent an explicit integrity decision.
- Use `@db.VarChar(n)` type annotations consistent with existing schema.
- After schema edits, the migration command is:
  ```bash
  cd backend && npx prisma migrate dev --name <descriptive_name>
  ```
- After migration, regenerate the client:
  ```bash
  npx prisma generate
  ```

### 4. PrismaClient singleton

The current codebase has `new PrismaClient()` in every model file — this is a known anti-pattern that exhausts connection pools under load. When fixing this, create a shared singleton:

```typescript
// backend/src/lib/prisma.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ?? new PrismaClient({ log: ['warn', 'error'] });

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
```

Then replace all `new PrismaClient()` imports in model files with `import { prisma } from '../../lib/prisma'`.

### 5. N+1 / sequential insert fixes

The `addCandidate` service currently saves related records in sequential `for` loops. Prefer Prisma nested writes or `createMany`:

**Preferred pattern — nested write in a single transaction:**
```typescript
await prisma.candidate.create({
  data: {
    firstName, lastName, email, phone, address,
    educations:      { createMany: { data: educations } },
    workExperiences: { createMany: { data: workExperiences } },
    resumes:         { createMany: { data: resumes } },
  },
});
```

**When operations must be independent — use `$transaction`:**
```typescript
await prisma.$transaction([
  prisma.education.createMany({ data: educations }),
  prisma.workExperience.createMany({ data: workExperiences }),
]);
```

### 6. Query optimization checklist

Before declaring a query optimized, verify:

- [ ] `findMany` has a `take` limit (never unbounded list queries)
- [ ] Relations are loaded with `include` only when the caller needs them (not by default)
- [ ] `select` is used to avoid returning large text fields (e.g., `filePath`) when not needed
- [ ] WHERE clause columns have a corresponding `@@index` in the schema
- [ ] Pagination uses cursor-based (`cursor` + `take`) for large tables, not offset (`skip` + `take`)

### 7. EXPLAIN ANALYZE workflow

When diagnosing a slow query, provide the raw SQL to run:

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ...;
```

Then interpret:
- `Seq Scan` on a large table → missing index
- `Hash Join` with high `rows` estimate → statistics may be stale, run `ANALYZE <table>`
- High `Buffers: shared hit` → query is cache-hot, look elsewhere for bottleneck
- `Nested Loop` with many iterations → N+1 at the DB level

### 8. Migration authoring rules

- Migration file names must be descriptive: `add_indexes_candidate_relations`, `add_cascade_delete_candidate`
- Never edit an already-applied migration file
- Raw SQL in migrations is acceptable for operations Prisma cannot express (e.g., partial indexes, `CREATE EXTENSION`, `CONCURRENTLY` index builds)
- Example partial index (add inside a migration SQL block):
  ```sql
  CREATE INDEX CONCURRENTLY idx_education_candidate_id ON "education"("candidateId");
  ```

### 9. Output format

When proposing changes, always structure your response as:

1. **Problem** — one sentence naming the issue
2. **Root cause** — why it happens in the current code
3. **Fix** — exact code diff or schema block to apply
4. **Migration command** — the exact `prisma migrate dev` command to run (if schema changed)
5. **Verification** — how to confirm the fix worked (query, EXPLAIN output, or test)

Do not propose fixes without showing the verification step.

## Project-specific context

This skill is calibrated for the LTI Talent Tracking System:

- Schema: `Candidate` → `Education`, `WorkExperience`, `Resume` (all one-to-many), plus full ATS models (`Company`, `Employee`, `InterviewFlow`, `InterviewType`, `InterviewStep`, `Position`, `Application`, `Interview`)
- Backend port: 3010 | Frontend port: 3000
- Prisma version: 5.x
- Known debt:
  - **PrismaClient singleton missing** — `new PrismaClient()` called independently in `Candidate.ts`, `Education.ts`, `WorkExperience.ts`, `Resume.ts`, `index.ts`, and `Education.test.ts`; exhausts the connection pool under load
  - **N+1 in `addCandidate`** — sequential `for` loops with individual `await educationModel.save()`, `await experienceModel.save()`, and `await resumeModel.save()` calls; should use nested `createMany` in a single transaction
  - **`Candidate.findOne` missing `include`** — calls `prisma.candidate.findUnique` with no `include` or `select`; returns a bare candidate with no related `educations`, `workExperiences`, or `resumes`
  - **Missing standalone index on `Application.candidateId`** — only a composite `@@unique([candidateId, positionId])` exists; queries filtering by `candidateId` alone (e.g., "all applications for a candidate") will not use that index
- DB credentials live in `.env` (never commit changes to that file)
- All schema changes go through `prisma migrate dev` — never alter the DB directly
