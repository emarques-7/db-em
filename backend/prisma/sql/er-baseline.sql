-- =============================================================================
-- ER Baseline SQL Script
-- Source: er.mmd (faithful translation, no enhancements)
-- Generated: 2026-04-26
-- =============================================================================

-- COMPANY
CREATE TABLE company (
    id   SERIAL,
    name VARCHAR(255) NOT NULL,
    CONSTRAINT pk_company PRIMARY KEY (id)
);

-- EMPLOYEE
CREATE TABLE employee (
    id         SERIAL,
    company_id INTEGER      NOT NULL,
    name       VARCHAR(255) NOT NULL,
    email      VARCHAR(255) NOT NULL,
    role       VARCHAR(100) NOT NULL,
    is_active  BOOLEAN      NOT NULL,
    CONSTRAINT pk_employee        PRIMARY KEY (id),
    CONSTRAINT fk_employee_company FOREIGN KEY (company_id) REFERENCES company (id)
);

-- INTERVIEW_FLOW
CREATE TABLE interview_flow (
    id          SERIAL,
    description VARCHAR(255) NOT NULL,
    CONSTRAINT pk_interview_flow PRIMARY KEY (id)
);

-- INTERVIEW_TYPE
CREATE TABLE interview_type (
    id          SERIAL,
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    CONSTRAINT pk_interview_type PRIMARY KEY (id)
);

-- POSITION
CREATE TABLE position (
    id                  SERIAL,
    company_id          INTEGER       NOT NULL,
    interview_flow_id   INTEGER       NOT NULL,
    title               VARCHAR(255)  NOT NULL,
    description         TEXT,
    status              VARCHAR(50)   NOT NULL,
    is_visible          BOOLEAN       NOT NULL,
    location            VARCHAR(255),
    job_description     TEXT,
    requirements        TEXT,
    responsibilities    TEXT,
    salary_min          NUMERIC(10,2),
    salary_max          NUMERIC(10,2),
    employment_type     VARCHAR(50),
    benefits            TEXT,
    company_description TEXT,
    application_deadline DATE,
    contact_info        VARCHAR(255),
    CONSTRAINT pk_position                  PRIMARY KEY (id),
    CONSTRAINT fk_position_company         FOREIGN KEY (company_id)        REFERENCES company       (id),
    CONSTRAINT fk_position_interview_flow  FOREIGN KEY (interview_flow_id) REFERENCES interview_flow (id)
);

-- INTERVIEW_STEP
CREATE TABLE interview_step (
    id                SERIAL,
    interview_flow_id INTEGER      NOT NULL,
    interview_type_id INTEGER      NOT NULL,
    name              VARCHAR(100) NOT NULL,
    order_index       INTEGER      NOT NULL,
    CONSTRAINT pk_interview_step               PRIMARY KEY (id),
    CONSTRAINT fk_interview_step_flow          FOREIGN KEY (interview_flow_id) REFERENCES interview_flow (id),
    CONSTRAINT fk_interview_step_type          FOREIGN KEY (interview_type_id) REFERENCES interview_type (id)
);

-- CANDIDATE
CREATE TABLE candidate (
    id         SERIAL,
    first_name VARCHAR(100) NOT NULL,
    last_name  VARCHAR(100) NOT NULL,
    email      VARCHAR(255) NOT NULL,
    phone      VARCHAR(15),
    address    VARCHAR(100),
    CONSTRAINT pk_candidate       PRIMARY KEY (id),
    CONSTRAINT uq_candidate_email UNIQUE      (email)
);

-- APPLICATION
CREATE TABLE application (
    id               SERIAL,
    position_id      INTEGER NOT NULL,
    candidate_id     INTEGER NOT NULL,
    application_date DATE    NOT NULL,
    status           VARCHAR(50) NOT NULL,
    notes            TEXT,
    CONSTRAINT pk_application              PRIMARY KEY (id),
    CONSTRAINT fk_application_position    FOREIGN KEY (position_id)  REFERENCES position  (id),
    CONSTRAINT fk_application_candidate   FOREIGN KEY (candidate_id) REFERENCES candidate (id)
);

-- INTERVIEW
CREATE TABLE interview (
    id                SERIAL,
    application_id    INTEGER NOT NULL,
    interview_step_id INTEGER NOT NULL,
    employee_id       INTEGER NOT NULL,
    interview_date    DATE    NOT NULL,
    result            VARCHAR(50),
    score             INTEGER,
    notes             TEXT,
    CONSTRAINT pk_interview                    PRIMARY KEY (id),
    CONSTRAINT fk_interview_application        FOREIGN KEY (application_id)    REFERENCES application    (id),
    CONSTRAINT fk_interview_step               FOREIGN KEY (interview_step_id) REFERENCES interview_step (id),
    CONSTRAINT fk_interview_employee           FOREIGN KEY (employee_id)       REFERENCES employee       (id)
);
