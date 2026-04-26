# db-schema-design

A skill for relational database schema design, normalization analysis, and PostgreSQL-native modeling in the LTI project. SQL-first thinking that maps back to Prisma schema.

## Trigger conditions

Use this skill when the user asks about:

- Normal form analysis or violations (1NF, 2NF, 3NF, BCNF)
- Schema design for new models or major restructuring
- Functional dependency identification
- Denormalization decisions and trade-offs
- Data integrity (check constraints, composite unique constraints)
- PostgreSQL-native types (`uuid`, `jsonb`, `enum`, arrays, `text` vs `varchar`)
- Table partitioning strategies
- Cascade rules (delete/update propagation)
- Splitting or merging models (decomposition / consolidation)
- "Is this schema correct?", "Is this normalized?", "Should I split this table?"

Do NOT use this skill for Prisma client patterns, query optimization, migration commands, or connection pooling — those belong to the `prisma-db` skill.

## Instructions

### 1. Always read the schema first

Before any analysis, read `backend/prisma/schema.prisma`. Never assess normalization from memory — the schema may have changed.

### 2. Normal form analysis workflow

Analyze each model in order. For each one, answer all three questions before moving on.

#### 1NF — First Normal Form
A table is in 1NF when:
- Every column holds atomic (indivisible) values
- No repeating groups or arrays stored as delimited strings
- Every row is uniquely identifiable (has a primary key)

**Red flags to look for:**
- A `VarChar` column storing comma-separated values (e.g., `skills: "python,java,sql"`)
- A column name like `phone1`, `phone2`, `phone3` (repeating group)
- No primary key

**Current schema status:**
- `Candidate.address` is a single `VarChar(100)` — borderline. A full address (street, city, country, postal code) stored as one string violates 1NF if you ever need to query by city or country. Flag for decomposition if querying by address components is needed.
- All other fields appear atomic. ✓

#### 2NF — Second Normal Form
A table is in 2NF when it is in 1NF AND every non-key attribute is fully functionally dependent on the entire primary key (only relevant for composite PKs).

**Red flags to look for:**
- A table with a composite PK where some columns depend on only part of the key
- Partial dependency: `(candidateId, institutionId) → institution_name` — `institution_name` depends only on `institutionId`, not the full key

**Current schema status:**
- All tables use a single-column surrogate PK (`id`). 2NF violations require composite PKs, so no 2NF violations exist by construction. ✓
- Note: if a composite PK is ever introduced, re-run 2NF analysis.

#### 3NF — Third Normal Form
A table is in 3NF when it is in 2NF AND no non-key attribute transitively depends on the primary key through another non-key attribute.

**Red flags to look for:**
- `A → B → C` where A is the PK, B and C are non-key: C should be in its own table
- Example: `WorkExperience.company → company_address` — `company_address` depends on `company`, not on `id`

**Current schema analysis:**

| Model | Transitive dependency risk | Verdict |
|-------|---------------------------|---------|
| `Candidate` | `address` is a free-text field — no transitive deps currently | ✓ 3NF |
| `Education` | `institution` and `title` are free text, no lookup table — if `institution → location` were added, violation would occur | ✓ 3NF for now |
| `WorkExperience` | `company` is free text — if company details were added (website, industry), transitive deps would arise | ✓ 3NF for now; flag if company details are added |
| `Resume` | `fileType` could imply a MIME type lookup — minor risk if `fileType → mimeDescription` were added | ✓ 3NF for now |

#### BCNF — Boyce-Codd Normal Form
Stricter than 3NF. Every determinant must be a candidate key.

**When to check:** Only necessary when a table has multiple overlapping candidate keys. Not currently applicable to this schema — flag for re-analysis if unique constraints are added to non-PK columns beyond `Candidate.email`.

---

### 3. Decomposition recommendations

When a normal form violation is found, follow this pattern:

1. **Name the violation** — which normal form, which table, which columns
2. **Show the functional dependency** — `X → Y` notation
3. **Propose the decomposition** — new model in Prisma schema syntax
4. **Show the trade-off** — what query complexity increases, what integrity improves
5. **Give the migration path** — data migration SQL + Prisma schema change

**Example decomposition (institution → its own table):**

```prisma
model Institution {
  id        Int         @id @default(autoincrement())
  name      String      @unique @db.VarChar(100)
  educations Education[]
}

model Education {
  id            Int         @id @default(autoincrement())
  institutionId Int
  institution   Institution @relation(fields: [institutionId], references: [id])
  title         String      @db.VarChar(250)
  startDate     DateTime
  endDate       DateTime?
  candidateId   Int
  candidate     Candidate   @relation(fields: [candidateId], references: [id])
}
```

Data migration SQL to include in the Prisma migration file:
```sql
INSERT INTO "institution" (name)
SELECT DISTINCT institution FROM "education";

ALTER TABLE "education" ADD COLUMN "institutionId" INTEGER;

UPDATE "education" e
SET "institutionId" = i.id
FROM "institution" i
WHERE i.name = e.institution;

ALTER TABLE "education" DROP COLUMN institution;
ALTER TABLE "education" ALTER COLUMN "institutionId" SET NOT NULL;
```

---

### 4. Denormalization decisions

Denormalization is intentional and must be justified. Only recommend it when:

- A normalized query requires 3+ joins and runs on a hot read path
- Aggregated values are read far more often than they change (e.g., a `candidateCount` on a company)
- Full-text search across related fields requires a materialized column

**Template for recommending denormalization:**
```
Denormalization proposal: add [column] to [table]
Reason: [query] runs [N] times per second and currently requires joining [X] tables
Trade-off: writes to [source table] must update [denormalized column] — use a DB trigger or application-layer sync
Rollback: column can be dropped and query reverted to join without data loss
```

Always document denormalized columns with a Prisma `/// denormalized from X.Y` comment so future developers know it is intentional.

---

### 5. PostgreSQL-native type recommendations

When a field's current type is a poor fit, recommend the native PostgreSQL type and its Prisma mapping:

| Use case | Avoid | Prefer | Prisma mapping |
|----------|-------|--------|----------------|
| Surrogate PK (distributed systems) | `Int @default(autoincrement())` | `String @default(uuid()) @db.Uuid` | `@db.Uuid` |
| Structured metadata / flexible attrs | `VarChar` JSON string | `Json` | `Json @db.JsonB` |
| Fixed-value categories | `VarChar` with app-level check | `enum` | `enum` in Prisma schema |
| Unbounded text (descriptions, bios) | `VarChar(n)` with arbitrary n | `String` (maps to `text`) | no `@db.VarChar` annotation |
| Email, phone (validated format) | `VarChar` only | `VarChar` + `CHECK` constraint in migration | add raw SQL check in migration |
| Timestamps with timezone | `DateTime` (maps to `timestamp`) | `DateTime @db.Timestamptz` | `@db.Timestamptz` |

**Current schema flags:**
- `Resume.fileType` — consider a Prisma `enum` (`PDF`, `DOCX`, `DOC`) if the set of accepted types is fixed; prevents invalid values at the DB level
- `Candidate.phone` — `VarChar(15)` is fine for E.164 format; add a `CHECK` constraint in a migration for format enforcement
- `WorkExperience.description` — `VarChar(200)` is artificially short for a description field; consider `String` (PostgreSQL `text`) with no length cap and enforce length in the application layer only

---

### 6. Integrity constraints

Beyond what Prisma expresses, recommend raw SQL constraints in migrations when needed:

```sql
-- Check constraint: endDate must be after startDate
ALTER TABLE "education"
  ADD CONSTRAINT chk_education_dates CHECK ("endDate" IS NULL OR "endDate" >= "startDate");

ALTER TABLE "work_experience"
  ADD CONSTRAINT chk_work_dates CHECK ("endDate" IS NULL OR "endDate" >= "startDate");

-- Check constraint: fileType whitelist
ALTER TABLE "resume"
  ADD CONSTRAINT chk_resume_filetype CHECK ("fileType" IN ('PDF', 'DOCX', 'DOC'));
```

Add these inside a Prisma migration SQL block. They are invisible to Prisma's schema but enforced by PostgreSQL.

---

### 7. Output format

Structure every response as:

1. **Schema read** — confirm you read the current `schema.prisma`
2. **Normal form verdict** — table-by-table, one line each: ✓ or violation + which NF + which columns
3. **Recommendations** — ordered by impact (highest first), each with:
   - Problem (NF violation or type mismatch)
   - Proposed change (Prisma schema block or SQL)
   - Trade-off (what gets harder, what gets better)
   - Migration path
4. **What NOT to change** — explicitly state what is already correct, so the user doesn't second-guess it

Always distinguish between **must fix** (actual NF violation) and **consider** (type improvement or integrity constraint that doesn't affect normalization).

## Project-specific context

Schema: 12 models — `Candidate`, `Education`, `WorkExperience`, `Resume`, `Company`, `Employee`, `InterviewFlow`, `InterviewType`, `InterviewStep`, `Position`, `Application`, `Interview`.

**Important:** always run normalization analysis across all 12 models. Do not limit analysis to the original four (`Candidate`, `Education`, `WorkExperience`, `Resume`) — the ATS models introduce new dependency risks.

Current normalization status (as of 2026-04-26):
- All 12 models satisfy 1NF, 2NF, 3NF for current fields
- All `DateTime` fields use `@db.Timestamptz` throughout — no timestamp conversions needed

Future risk areas:
- `Education.institution` — if institution metadata (location, accreditation) is added, extract to its own table
- `WorkExperience.company` — if company details (website, industry) are added, transitive deps arise; consider FK to `Company`
- `Candidate.address` — single `VarChar(100)`; decompose into structured fields if querying by city/country is needed
- `Company` — currently only has `name`; adding `industry`, `size`, `website` later is safe, but adding fields that depend on each other (e.g., `region → timezone`) would introduce 3NF risk
- `Employee.role` — enforced as enum; safe as long as the enum values remain a closed set
- `Position` — `contactInfo` is non-atomic free text; decompose if contact fields need independent querying
- `InterviewStep.orderIndex` — unique per flow (composite unique enforced); verify no business logic assumes gaps are forbidden

Type improvement candidates:
- `Resume.fileType` — consider a Prisma `enum` (`PDF`, `DOCX`, `DOC`) if the accepted set is fixed
- `WorkExperience.description` — `VarChar(200)` is short; consider `String` (PostgreSQL `text`) with app-layer length enforcement only
- `Position.salaryMin` / `salaryMax` — `Decimal(10,2)` is correct; verify currency handling if multi-currency support is added

Missing DB-level integrity constraints:
- Date range checks on `education` and `work_experience`: `endDate >= startDate`
- Date range check on `interview`: `interviewDate` should not be in the past for newly scheduled interviews (application-layer concern, but worth noting)
- `CHECK (salaryMin <= salaryMax)` on `position` — already applied in migration ✓
- `CHECK (score BETWEEN 0 AND 100)` on `interview` — already applied in migration ✓
- `fileType` whitelist on `resume` — not yet enforced at DB level
- No check on `Application.applicationDate` vs `Position.applicationDeadline` — enforce at application layer
