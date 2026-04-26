-- =============================================================================
-- Migration: enhanced_ats_schema
-- Clean-slate migration: creates all tables (existing models + new ATS models).
-- Date: 2026-04-26
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. PostgreSQL ENUM types
-- ---------------------------------------------------------------------------

CREATE TYPE "EmployeeRole"      AS ENUM ('ADMIN', 'MANAGER', 'HR', 'INTERVIEWER');
CREATE TYPE "PositionStatus"    AS ENUM ('DRAFT', 'OPEN', 'CLOSED', 'CANCELLED');
CREATE TYPE "EmploymentType"    AS ENUM ('FULL_TIME', 'PART_TIME', 'CONTRACT', 'INTERNSHIP', 'REMOTE');
CREATE TYPE "ApplicationStatus" AS ENUM ('PENDING', 'REVIEWING', 'SELECTED', 'REJECTED', 'WITHDRAWN');
CREATE TYPE "InterviewResult"   AS ENUM ('PASS', 'FAIL', 'PENDING', 'CANCELLED');

-- ---------------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------------

CREATE TABLE candidate (
    id          SERIAL PRIMARY KEY,
    "firstName" VARCHAR(100) NOT NULL,
    "lastName"  VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    phone       VARCHAR(15),
    address     VARCHAR(100)
);

CREATE UNIQUE INDEX "candidate_email_key" ON candidate (email);

CREATE TABLE education (
    id            SERIAL PRIMARY KEY,
    institution   VARCHAR(100) NOT NULL,
    title         VARCHAR(250) NOT NULL,
    "startDate"   TIMESTAMPTZ  NOT NULL,
    "endDate"     TIMESTAMPTZ,
    "candidateId" INTEGER      NOT NULL,
    CONSTRAINT "education_candidateId_fkey"
      FOREIGN KEY ("candidateId") REFERENCES candidate (id)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "chk_education_dates"
      CHECK ("endDate" IS NULL OR "endDate" >= "startDate")
);

CREATE INDEX "education_candidateId_idx" ON education ("candidateId");

CREATE TABLE work_experience (
    id            SERIAL PRIMARY KEY,
    company       VARCHAR(100) NOT NULL,
    position      VARCHAR(100) NOT NULL,
    description   TEXT,
    "startDate"   TIMESTAMPTZ  NOT NULL,
    "endDate"     TIMESTAMPTZ,
    "candidateId" INTEGER      NOT NULL,
    CONSTRAINT "work_experience_candidateId_fkey"
      FOREIGN KEY ("candidateId") REFERENCES candidate (id)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "chk_work_experience_dates"
      CHECK ("endDate" IS NULL OR "endDate" >= "startDate")
);

CREATE INDEX "work_experience_candidateId_idx" ON work_experience ("candidateId");

CREATE TABLE resume (
    id            SERIAL PRIMARY KEY,
    "filePath"    VARCHAR(500) NOT NULL,
    "fileType"    VARCHAR(50)  NOT NULL,
    "uploadDate"  TIMESTAMPTZ  NOT NULL,
    "candidateId" INTEGER      NOT NULL,
    CONSTRAINT "resume_candidateId_fkey"
      FOREIGN KEY ("candidateId") REFERENCES candidate (id)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX "resume_candidateId_idx" ON resume ("candidateId");

CREATE TABLE company (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE TABLE employee (
    id          SERIAL PRIMARY KEY,
    "companyId" INTEGER        NOT NULL,
    name        VARCHAR(255)   NOT NULL,
    email       VARCHAR(255)   NOT NULL,
    role        "EmployeeRole" NOT NULL,
    "isActive"  BOOLEAN        NOT NULL DEFAULT false,
    CONSTRAINT "employee_companyId_fkey"
      FOREIGN KEY ("companyId") REFERENCES company (id)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "employee_email_key"    ON employee (email);
CREATE INDEX        "employee_companyId_idx" ON employee ("companyId");

CREATE TABLE interview_flow (
    id          SERIAL PRIMARY KEY,
    description TEXT NOT NULL
);

CREATE TABLE interview_type (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    description TEXT
);

CREATE TABLE interview_step (
    id                SERIAL PRIMARY KEY,
    "interviewFlowId" INTEGER      NOT NULL,
    "interviewTypeId" INTEGER      NOT NULL,
    name              VARCHAR(100) NOT NULL,
    "orderIndex"      INTEGER      NOT NULL,
    CONSTRAINT "interview_step_interviewFlowId_fkey"
      FOREIGN KEY ("interviewFlowId") REFERENCES interview_flow (id)
      ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT "interview_step_interviewTypeId_fkey"
      FOREIGN KEY ("interviewTypeId") REFERENCES interview_type (id)
      ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "interview_step_interviewFlowId_orderIndex_key"
  ON interview_step ("interviewFlowId", "orderIndex");
CREATE INDEX "interview_step_interviewTypeId_idx" ON interview_step ("interviewTypeId");

CREATE TABLE position (
    id                    SERIAL PRIMARY KEY,
    "companyId"           INTEGER          NOT NULL,
    "interviewFlowId"     INTEGER          NOT NULL,
    title                 VARCHAR(255)     NOT NULL,
    description           TEXT,
    status                "PositionStatus" NOT NULL DEFAULT 'DRAFT',
    "isVisible"           BOOLEAN          NOT NULL DEFAULT false,
    location              VARCHAR(255),
    "jobDescription"      TEXT,
    requirements          TEXT,
    responsibilities      TEXT,
    "salaryMin"           NUMERIC(10,2),
    "salaryMax"           NUMERIC(10,2),
    "employmentType"      "EmploymentType",
    benefits              TEXT,
    "companyDescription"  TEXT,
    "applicationDeadline" TIMESTAMPTZ,
    "contactInfo"         VARCHAR(255),
    "createdAt"           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt"           TIMESTAMPTZ NOT NULL,
    CONSTRAINT "position_companyId_fkey"
      FOREIGN KEY ("companyId") REFERENCES company (id)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "position_interviewFlowId_fkey"
      FOREIGN KEY ("interviewFlowId") REFERENCES interview_flow (id)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "chk_position_salary"
      CHECK ("salaryMin" IS NULL OR "salaryMax" IS NULL OR "salaryMin" <= "salaryMax")
);

CREATE INDEX "position_companyId_idx"            ON position ("companyId");
CREATE INDEX "position_interviewFlowId_idx"      ON position ("interviewFlowId");
CREATE INDEX "position_status_idx"               ON position (status);
CREATE INDEX "position_applicationDeadline_idx"  ON position ("applicationDeadline");

CREATE TABLE application (
    id                SERIAL PRIMARY KEY,
    "positionId"      INTEGER             NOT NULL,
    "candidateId"     INTEGER             NOT NULL,
    "applicationDate" TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    status            "ApplicationStatus" NOT NULL DEFAULT 'PENDING',
    notes             TEXT,
    "createdAt"       TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    "updatedAt"       TIMESTAMPTZ         NOT NULL,
    CONSTRAINT "application_positionId_fkey"
      FOREIGN KEY ("positionId") REFERENCES position (id)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "application_candidateId_fkey"
      FOREIGN KEY ("candidateId") REFERENCES candidate (id)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "application_candidateId_positionId_key"
      UNIQUE ("candidateId", "positionId")
);

CREATE INDEX "application_positionId_idx"  ON application ("positionId");
CREATE INDEX "application_candidateId_idx" ON application ("candidateId");
CREATE INDEX "application_status_idx"      ON application (status);

CREATE TABLE interview (
    id                SERIAL PRIMARY KEY,
    "applicationId"   INTEGER           NOT NULL,
    "interviewStepId" INTEGER           NOT NULL,
    "employeeId"      INTEGER           NOT NULL,
    "interviewDate"   TIMESTAMPTZ       NOT NULL,
    result            "InterviewResult" NOT NULL DEFAULT 'PENDING',
    score             INTEGER,
    notes             TEXT,
    "createdAt"       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt"       TIMESTAMPTZ NOT NULL,
    CONSTRAINT "interview_applicationId_fkey"
      FOREIGN KEY ("applicationId") REFERENCES application (id)
      ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT "interview_interviewStepId_fkey"
      FOREIGN KEY ("interviewStepId") REFERENCES interview_step (id)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "interview_employeeId_fkey"
      FOREIGN KEY ("employeeId") REFERENCES employee (id)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "chk_interview_score"
      CHECK (score IS NULL OR (score >= 0 AND score <= 100))
);

CREATE INDEX "interview_applicationId_idx"    ON interview ("applicationId");
CREATE INDEX "interview_interviewStepId_idx"  ON interview ("interviewStepId");
CREATE INDEX "interview_employeeId_idx"       ON interview ("employeeId");
