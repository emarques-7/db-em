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

```prisma
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
}

model Education {
  id          Int       @id @default(autoincrement())
  institution String    @db.VarChar(100)
  title       String    @db.VarChar(250)
  startDate   DateTime
  endDate     DateTime?
  candidateId Int
  candidate   Candidate @relation(fields: [candidateId], references: [id])
}

model WorkExperience {
  id          Int       @id @default(autoincrement())
  company     String    @db.VarChar(100)
  position    String    @db.VarChar(100)
  description String?   @db.VarChar(200)
  startDate   DateTime
  endDate     DateTime?
  candidateId Int
  candidate   Candidate @relation(fields: [candidateId], references: [id])
}

model Resume {
  id          Int      @id @default(autoincrement())
  filePath    String   @db.VarChar(500)
  fileType    String   @db.VarChar(50)
  uploadDate  DateTime
  candidateId Int
  candidate   Candidate @relation(fields: [candidateId], references: [id])
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
