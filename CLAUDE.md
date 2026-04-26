# LTI - Talent Tracking System

Full-stack ATS (Applicant Tracking System) with a React frontend and an Express/TypeScript backend using Prisma 5.x as ORM against PostgreSQL.

## Stack

| Layer      | Technology                                  |
|------------|---------------------------------------------|
| Frontend   | React (Create React App), JavaScript        |
| Backend    | Node.js, TypeScript, Express 4.x            |
| ORM        | Prisma 5.x (`@prisma/client`)               |
| Database   | PostgreSQL (Docker via `docker-compose.yml`)|
| Testing    | Jest + ts-jest                              |

## Project Structure

```
.
├── docker-compose.yml       # PostgreSQL service
├── .env                     # DB credentials + DATABASE_URL
├── frontend/                # React app (CRA)
│   └── src/
│       ├── components/      # UI components
│       └── services/        # API client calls
└── backend/
    ├── prisma/
    │   ├── schema.prisma    # Prisma schema (single source of truth for DB)
    │   └── migrations/      # Migration history
    └── src/
        ├── index.ts                        # Express entry point (port 3010)
        ├── routes/                         # Route definitions
        ├── application/
        │   ├── services/                   # Business logic (candidateService.ts)
        │   └── validator.ts               # Input validation (regex-based)
        ├── domain/
        │   └── models/                     # Active Record models wrapping PrismaClient
        └── presentation/
            └── controllers/               # HTTP handlers
```

## Database Schema (Prisma)

See [`backend/prisma/schema.prisma`](backend/prisma/schema.prisma) for the authoritative source. Summary below.

**Enums:** `EmployeeRole` · `PositionStatus` · `EmploymentType` · `ApplicationStatus` · `InterviewResult`

```prisma
// ---------------------------------------------------------------------------
// Existing models (enhanced)
// ---------------------------------------------------------------------------

model Candidate {
  id              Int              @id @default(autoincrement())
  firstName       String           @db.VarChar(100)
  lastName        String           @db.VarChar(100)
  email           String           @unique @db.VarChar(255)
  phone           String?          @db.VarChar(15)
  address         String?          @db.VarChar(100)
  educations      Education[]
  workExperiences WorkExperience[]
  resumes         Resume[]
  applications    Application[]

  @@map("candidate")
}

model Education {
  id          Int       @id @default(autoincrement())
  institution String    @db.VarChar(100)
  title       String    @db.VarChar(250)
  startDate   DateTime  @db.Timestamptz
  endDate     DateTime? @db.Timestamptz
  candidateId Int
  candidate   Candidate @relation(fields: [candidateId], references: [id], onDelete: Restrict)

  @@index([candidateId])
  @@map("education")
}

model WorkExperience {
  id          Int       @id @default(autoincrement())
  company     String    @db.VarChar(100)
  position    String    @db.VarChar(100)
  description String?
  startDate   DateTime  @db.Timestamptz
  endDate     DateTime? @db.Timestamptz
  candidateId Int
  candidate   Candidate @relation(fields: [candidateId], references: [id], onDelete: Restrict)

  @@index([candidateId])
  @@map("work_experience")
}

model Resume {
  id          Int      @id @default(autoincrement())
  filePath    String   @db.VarChar(500)
  fileType    String   @db.VarChar(50)
  uploadDate  DateTime @db.Timestamptz
  candidateId Int
  candidate   Candidate @relation(fields: [candidateId], references: [id], onDelete: Restrict)

  @@index([candidateId])
  @@map("resume")
}

// ---------------------------------------------------------------------------
// ATS models
// ---------------------------------------------------------------------------

model Company {
  id        Int        @id @default(autoincrement())
  name      String     @db.VarChar(255)
  employees Employee[]
  positions Position[]

  @@map("company")
}

model Employee {
  id        Int          @id @default(autoincrement())
  companyId Int
  company   Company      @relation(fields: [companyId], references: [id], onDelete: Restrict)
  name      String       @db.VarChar(255)
  email     String       @unique @db.VarChar(255)
  role      EmployeeRole
  isActive  Boolean      @default(false)
  interviews Interview[]

  @@index([companyId])
  @@map("employee")
}

model InterviewFlow {
  id             Int             @id @default(autoincrement())
  description    String
  interviewSteps InterviewStep[]
  positions      Position[]

  @@map("interview_flow")
}

model InterviewType {
  id             Int             @id @default(autoincrement())
  name           String          @db.VarChar(100)
  description    String?
  interviewSteps InterviewStep[]

  @@map("interview_type")
}

model InterviewStep {
  id              Int           @id @default(autoincrement())
  interviewFlowId Int
  interviewFlow   InterviewFlow @relation(fields: [interviewFlowId], references: [id], onDelete: Cascade)
  interviewTypeId Int
  interviewType   InterviewType @relation(fields: [interviewTypeId], references: [id], onDelete: Restrict)
  name            String        @db.VarChar(100)
  orderIndex      Int
  interviews      Interview[]

  @@unique([interviewFlowId, orderIndex])
  @@index([interviewTypeId])
  @@map("interview_step")
}

model Position {
  id                  Int             @id @default(autoincrement())
  companyId           Int
  company             Company         @relation(fields: [companyId], references: [id], onDelete: Restrict)
  interviewFlowId     Int
  interviewFlow       InterviewFlow   @relation(fields: [interviewFlowId], references: [id], onDelete: Restrict)
  title               String          @db.VarChar(255)
  description         String?
  status              PositionStatus  @default(DRAFT)
  isVisible           Boolean         @default(false)
  location            String?         @db.VarChar(255)
  jobDescription      String?
  requirements        String?
  responsibilities    String?
  salaryMin           Decimal?        @db.Decimal(10, 2)
  salaryMax           Decimal?        @db.Decimal(10, 2)
  employmentType      EmploymentType?
  benefits            String?
  companyDescription  String?
  applicationDeadline DateTime?       @db.Timestamptz
  contactInfo         String?         @db.VarChar(255)
  applications        Application[]
  createdAt           DateTime        @default(now()) @db.Timestamptz
  updatedAt           DateTime        @updatedAt @db.Timestamptz

  @@index([companyId])
  @@index([interviewFlowId])
  @@index([status])
  @@index([applicationDeadline])
  @@map("position")
}

model Application {
  id              Int               @id @default(autoincrement())
  positionId      Int
  position        Position          @relation(fields: [positionId], references: [id], onDelete: Restrict)
  candidateId     Int
  candidate       Candidate         @relation(fields: [candidateId], references: [id], onDelete: Restrict)
  applicationDate DateTime          @default(now()) @db.Timestamptz
  status          ApplicationStatus @default(PENDING)
  notes           String?
  interviews      Interview[]
  createdAt       DateTime          @default(now()) @db.Timestamptz
  updatedAt       DateTime          @updatedAt @db.Timestamptz

  @@unique([candidateId, positionId])
  @@index([positionId])
  @@index([candidateId])
  @@index([status])
  @@map("application")
}

model Interview {
  id              Int             @id @default(autoincrement())
  applicationId   Int
  application     Application     @relation(fields: [applicationId], references: [id], onDelete: Cascade)
  interviewStepId Int
  interviewStep   InterviewStep   @relation(fields: [interviewStepId], references: [id], onDelete: Restrict)
  employeeId      Int
  employee        Employee        @relation(fields: [employeeId], references: [id], onDelete: Restrict)
  interviewDate   DateTime        @db.Timestamptz
  result          InterviewResult @default(PENDING)
  score           Int?
  notes           String?
  createdAt       DateTime        @default(now()) @db.Timestamptz
  updatedAt       DateTime        @updatedAt @db.Timestamptz

  @@index([applicationId])
  @@index([interviewStepId])
  @@index([employeeId])
  @@map("interview")
}
```

## Development Workflow

```bash
# Start the database
docker compose up -d

# Backend dev server (port 3010)
cd backend && npm run dev

# Frontend dev server (port 3000)
cd frontend && npm start

# Prisma
npx prisma migrate dev --name <migration_name>   # create + apply migration
npx prisma migrate deploy                         # apply in production
npx prisma generate                               # regenerate client after schema change
npx prisma studio                                 # visual DB browser

# Tests
cd backend && npm test
```

## Environment

```
DB_USER=LTIdbUser
DB_NAME=LTIdb
DB_PORT=5432
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}"
```

## Conventions

- Domain models use the Active Record pattern — each class owns its own `save()` and static `findOne()`.
- Validation lives in `application/validator.ts`; it is called at the service layer before any DB operation.
- All DB operations go through Prisma — no raw SQL except in migrations when needed.
- Migrations are the only place to write raw SQL (`-- sql` blocks inside a migration file).
- `prisma/schema.prisma` is the source of truth; never alter the DB schema directly.
- Backend runs on port **3010**, frontend on **3000**. CORS is configured for `http://localhost:3000` only.
