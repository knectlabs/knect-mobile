# Kerjancok — Database ERD

> Mermaid ER diagrams are intentionally included in Markdown so AI tools and humans can parse the data model without image OCR.

# 1. Naming Rules

- tables use plural snake_case in PostgreSQL where practical
- Prisma model names may use PascalCase
- IDs should be UUID/CUID consistently
- tenant-owned tables include `organization_id` when practical
- all operational records include `created_at`
- mutable records include `updated_at`

---

# 2. Master Domain Map

```mermaid
erDiagram
    ORGANIZATION ||--o{ USER : has
    ORGANIZATION ||--o{ DEPARTMENT : has
    ORGANIZATION ||--o{ POSITION : has
    ORGANIZATION ||--o{ OFFICE : has
    ORGANIZATION ||--o{ EMPLOYEE : employs
    ORGANIZATION ||--o{ SHIFT : defines
    ORGANIZATION ||--o{ LEAVE_TYPE : defines
    ORGANIZATION ||--o{ PAYROLL_PERIOD : runs
    ORGANIZATION ||--o{ JOB_OPENING : publishes

    USER ||--o{ REFRESH_TOKEN : owns
    USER ||--o{ DEVICE : registers
    USER ||--o{ NOTIFICATION : receives
    USER ||--o{ AUDIT_LOG : performs
    USER o|--o| EMPLOYEE : linked_account

    DEPARTMENT ||--o{ POSITION : contains
    DEPARTMENT ||--o{ EMPLOYEE : contains
    POSITION ||--o{ EMPLOYEE : assigned

    EMPLOYEE ||--o{ EMPLOYEE_SHIFT : scheduled
    SHIFT ||--o{ EMPLOYEE_SHIFT : used_by

    EMPLOYEE ||--o{ ATTENDANCE_RECORD : creates
    ATTENDANCE_RECORD ||--o{ ATTENDANCE_EVIDENCE : has
    ATTENDANCE_RECORD ||--o{ ATTENDANCE_ANOMALY : flags

    EMPLOYEE ||--o{ LEAVE_BALANCE : owns
    LEAVE_TYPE ||--o{ LEAVE_BALANCE : categorizes
    EMPLOYEE ||--o{ LEAVE_REQUEST : submits
    LEAVE_TYPE ||--o{ LEAVE_REQUEST : categorizes

    EMPLOYEE ||--o{ OVERTIME_REQUEST : submits

    APPROVAL_REQUEST ||--o{ APPROVAL_STEP : contains

    PAYROLL_PERIOD ||--o{ PAYROLL_EMPLOYEE : contains
    EMPLOYEE ||--o{ PAYROLL_EMPLOYEE : receives
    PAYROLL_EMPLOYEE ||--o{ PAYROLL_LINE : consists_of

    EMPLOYEE ||--o{ PERFORMANCE_GOAL : owns
    EMPLOYEE ||--o{ PERFORMANCE_REVIEW : receives
    PERFORMANCE_REVIEW ||--o{ REVIEW_ANSWER : contains

    JOB_OPENING ||--o{ CANDIDATE_APPLICATION : receives
```

---

# 3. Core HR

```mermaid
erDiagram
    ORGANIZATION {
        uuid id PK
        string name
        string code UK
        string timezone
        string address
        string phone
        string email
        boolean is_active
        datetime created_at
        datetime updated_at
    }

    USER {
        uuid id PK
        uuid organization_id FK
        uuid employee_id FK
        string email
        string password_hash
        string role
        boolean is_active
        datetime last_login_at
        datetime created_at
        datetime updated_at
    }

    EMPLOYEE {
        uuid id PK
        uuid organization_id FK
        uuid department_id FK
        uuid position_id FK
        uuid manager_id FK
        uuid office_id FK
        string employee_code
        string full_name
        string email
        string phone
        date join_date
        date termination_date
        string employment_status
        string profile_photo_url
        datetime created_at
        datetime updated_at
    }

    DEPARTMENT {
        uuid id PK
        uuid organization_id FK
        uuid parent_id FK
        string name
        string code
        boolean is_active
        datetime created_at
        datetime updated_at
    }

    POSITION {
        uuid id PK
        uuid organization_id FK
        uuid department_id FK
        string name
        string code
        boolean is_active
        datetime created_at
        datetime updated_at
    }

    OFFICE {
        uuid id PK
        uuid organization_id FK
        string name
        string address
        decimal latitude
        decimal longitude
        int geofence_radius_m
        string timezone
        boolean is_active
        datetime created_at
        datetime updated_at
    }

    ORGANIZATION ||--o{ USER : has
    ORGANIZATION ||--o{ EMPLOYEE : employs
    ORGANIZATION ||--o{ DEPARTMENT : has
    ORGANIZATION ||--o{ POSITION : has
    ORGANIZATION ||--o{ OFFICE : has

    USER o|--o| EMPLOYEE : linked_account
    DEPARTMENT ||--o{ POSITION : contains
    DEPARTMENT ||--o{ EMPLOYEE : assigned
    POSITION ||--o{ EMPLOYEE : assigned
    OFFICE ||--o{ EMPLOYEE : default_office
    EMPLOYEE o|--o{ EMPLOYEE : manages
```

---

# 4. Authentication & Device Sessions

```mermaid
erDiagram
    USER {
        uuid id PK
    }

    REFRESH_TOKEN {
        uuid id PK
        uuid user_id FK
        uuid device_id FK
        string token_hash
        datetime expires_at
        datetime revoked_at
        uuid replaced_by_id
        datetime created_at
    }

    DEVICE {
        uuid id PK
        uuid user_id FK
        string device_identifier
        string platform
        string model
        string push_token
        boolean is_active
        datetime last_used_at
        datetime created_at
        datetime updated_at
    }

    USER ||--o{ REFRESH_TOKEN : owns
    USER ||--o{ DEVICE : registers
    DEVICE ||--o{ REFRESH_TOKEN : sessions
```

---

# 5. Shift & Scheduling

```mermaid
erDiagram
    SHIFT {
        uuid id PK
        uuid organization_id FK
        uuid office_id FK
        string name
        time start_time
        time end_time
        int grace_minutes
        int break_minutes
        int clock_in_before_minutes
        int clock_in_after_minutes
        int clock_out_before_minutes
        int clock_out_after_minutes
        boolean crosses_midnight
        boolean is_active
        datetime created_at
        datetime updated_at
    }

    EMPLOYEE_SHIFT {
        uuid id PK
        uuid organization_id FK
        uuid employee_id FK
        uuid shift_id FK
        date start_date
        date end_date
        boolean is_active
        datetime created_at
        datetime updated_at
    }

    OFFICE ||--o{ SHIFT : hosts
    SHIFT ||--o{ EMPLOYEE_SHIFT : assigned
    EMPLOYEE ||--o{ EMPLOYEE_SHIFT : scheduled
```

Recommended future extension:

```text
work_schedules
schedule_days
holiday_calendars
holidays
```

Do not add until Phase 1 scheduling limitations require them.

---

# 6. Attendance

```mermaid
erDiagram
    ATTENDANCE_RECORD {
        uuid id PK
        uuid organization_id FK
        uuid employee_id FK
        uuid shift_id FK
        uuid office_id FK
        date attendance_date

        datetime clock_in_at
        datetime clock_out_at

        decimal clock_in_latitude
        decimal clock_in_longitude
        decimal clock_in_accuracy_m
        decimal clock_in_distance_m

        decimal clock_out_latitude
        decimal clock_out_longitude
        decimal clock_out_accuracy_m
        decimal clock_out_distance_m

        string clock_in_method
        string clock_out_method

        string status
        int late_minutes
        int early_leave_minutes
        int work_minutes
        int overtime_minutes

        boolean clock_in_location_valid
        boolean clock_out_location_valid
        boolean is_suspicious
        string risk_level

        datetime created_at
        datetime updated_at
    }

    ATTENDANCE_EVIDENCE {
        uuid id PK
        uuid attendance_id FK
        string evidence_type
        string file_url
        json metadata
        datetime created_at
    }

    ATTENDANCE_ANOMALY {
        uuid id PK
        uuid attendance_id FK
        string anomaly_type
        string severity
        string description
        json metadata
        boolean resolved
        uuid resolved_by_user_id FK
        datetime resolved_at
        datetime created_at
    }

    EMPLOYEE ||--o{ ATTENDANCE_RECORD : records
    SHIFT ||--o{ ATTENDANCE_RECORD : scheduled_as
    OFFICE ||--o{ ATTENDANCE_RECORD : validated_against
    ATTENDANCE_RECORD ||--o{ ATTENDANCE_EVIDENCE : includes
    ATTENDANCE_RECORD ||--o{ ATTENDANCE_ANOMALY : flags
```

Important unique rule:

```text
UNIQUE(employee_id, attendance_date)
```

This may later need expansion if multiple attendance sessions per day are supported.

---

# 7. Leave

```mermaid
erDiagram
    LEAVE_TYPE {
        uuid id PK
        uuid organization_id FK
        string name
        string code
        decimal default_quota
        boolean paid
        boolean requires_proof
        int minimum_notice_days
        boolean is_active
        datetime created_at
        datetime updated_at
    }

    LEAVE_BALANCE {
        uuid id PK
        uuid organization_id FK
        uuid employee_id FK
        uuid leave_type_id FK
        int year
        decimal opening_balance
        decimal earned
        decimal used
        decimal adjusted
        decimal remaining
        datetime created_at
        datetime updated_at
    }

    LEAVE_REQUEST {
        uuid id PK
        uuid organization_id FK
        uuid employee_id FK
        uuid leave_type_id FK
        date start_date
        date end_date
        decimal requested_days
        string reason
        string proof_url
        string status
        datetime submitted_at
        datetime cancelled_at
        datetime created_at
        datetime updated_at
    }

    EMPLOYEE ||--o{ LEAVE_BALANCE : owns
    LEAVE_TYPE ||--o{ LEAVE_BALANCE : categorizes
    EMPLOYEE ||--o{ LEAVE_REQUEST : submits
    LEAVE_TYPE ||--o{ LEAVE_REQUEST : categorizes
```

---

# 8. Overtime

```mermaid
erDiagram
    OVERTIME_REQUEST {
        uuid id PK
        uuid organization_id FK
        uuid employee_id FK
        date overtime_date
        datetime start_at
        datetime end_at
        int requested_minutes
        int approved_minutes
        string reason
        string status
        datetime submitted_at
        datetime created_at
        datetime updated_at
    }

    EMPLOYEE ||--o{ OVERTIME_REQUEST : submits
```

---

# 9. Reusable Approval Engine

```mermaid
erDiagram
    APPROVAL_REQUEST {
        uuid id PK
        uuid organization_id FK
        uuid requester_employee_id FK
        string target_type
        uuid target_id
        int current_step
        string status
        datetime completed_at
        datetime created_at
        datetime updated_at
    }

    APPROVAL_STEP {
        uuid id PK
        uuid approval_request_id FK
        int step_order
        uuid approver_employee_id FK
        string status
        string action
        string comment
        datetime acted_at
        datetime created_at
    }

    APPROVAL_REQUEST ||--o{ APPROVAL_STEP : contains
    EMPLOYEE ||--o{ APPROVAL_REQUEST : requests
    EMPLOYEE ||--o{ APPROVAL_STEP : approves
```

`target_type` examples:

- LEAVE_REQUEST
- OVERTIME_REQUEST
- ATTENDANCE_CORRECTION
- SHIFT_CHANGE

Avoid hardcoding separate approval-table structures per module.

---

# 10. Attendance Correction

Recommended Phase 1 entity:

```mermaid
erDiagram
    ATTENDANCE_CORRECTION_REQUEST {
        uuid id PK
        uuid organization_id FK
        uuid employee_id FK
        uuid attendance_id FK
        datetime requested_clock_in_at
        datetime requested_clock_out_at
        string reason
        string attachment_url
        string status
        datetime created_at
        datetime updated_at
    }

    EMPLOYEE ||--o{ ATTENDANCE_CORRECTION_REQUEST : submits
    ATTENDANCE_RECORD ||--o{ ATTENDANCE_CORRECTION_REQUEST : corrected_by
```

When approved:
- do not overwrite history silently
- update attendance through an audited service
- preserve correction request

---

# 11. Payroll

```mermaid
erDiagram
    PAYROLL_PERIOD {
        uuid id PK
        uuid organization_id FK
        string name
        date start_date
        date end_date
        string status
        datetime finalized_at
        datetime created_at
        datetime updated_at
    }

    PAYROLL_EMPLOYEE {
        uuid id PK
        uuid organization_id FK
        uuid payroll_period_id FK
        uuid employee_id FK
        decimal basic_salary
        decimal total_allowance
        decimal overtime_amount
        decimal gross_salary
        decimal total_deduction
        decimal tax_amount
        decimal net_salary
        string status
        datetime created_at
        datetime updated_at
    }

    PAYROLL_LINE {
        uuid id PK
        uuid payroll_employee_id FK
        string component_type
        string code
        string name
        decimal quantity
        decimal rate
        decimal amount
        json metadata
        datetime created_at
    }

    PAYROLL_PERIOD ||--o{ PAYROLL_EMPLOYEE : contains
    EMPLOYEE ||--o{ PAYROLL_EMPLOYEE : receives
    PAYROLL_EMPLOYEE ||--o{ PAYROLL_LINE : consists_of
```

Future configuration tables:

```text
salary_components
employee_salary_components
payroll_rules
tax_profiles
bpjs_profiles
bank_accounts
```

Keep configuration separate from payroll snapshots.

---

# 12. Performance

```mermaid
erDiagram
    PERFORMANCE_GOAL {
        uuid id PK
        uuid organization_id FK
        uuid employee_id FK
        string title
        string description
        string goal_type
        decimal target_value
        decimal current_value
        decimal weight
        date start_date
        date end_date
        string status
        datetime created_at
        datetime updated_at
    }

    REVIEW_CYCLE {
        uuid id PK
        uuid organization_id FK
        string name
        date start_date
        date end_date
        string status
        datetime created_at
        datetime updated_at
    }

    PERFORMANCE_REVIEW {
        uuid id PK
        uuid organization_id FK
        uuid review_cycle_id FK
        uuid employee_id FK
        uuid reviewer_employee_id FK
        string review_type
        decimal overall_rating
        string status
        datetime submitted_at
        datetime created_at
        datetime updated_at
    }

    REVIEW_ANSWER {
        uuid id PK
        uuid performance_review_id FK
        string question_key
        decimal rating
        string answer
        datetime created_at
        datetime updated_at
    }

    EMPLOYEE ||--o{ PERFORMANCE_GOAL : owns
    REVIEW_CYCLE ||--o{ PERFORMANCE_REVIEW : contains
    EMPLOYEE ||--o{ PERFORMANCE_REVIEW : receives
    EMPLOYEE ||--o{ PERFORMANCE_REVIEW : writes
    PERFORMANCE_REVIEW ||--o{ REVIEW_ANSWER : contains
```

---

# 13. Recruitment

```mermaid
erDiagram
    JOB_OPENING {
        uuid id PK
        uuid organization_id FK
        uuid department_id FK
        uuid position_id FK
        string title
        string description
        string employment_type
        string location
        string status
        datetime published_at
        datetime closed_at
        datetime created_at
        datetime updated_at
    }

    CANDIDATE {
        uuid id PK
        uuid organization_id FK
        string full_name
        string email
        string phone
        string resume_url
        datetime created_at
        datetime updated_at
    }

    CANDIDATE_APPLICATION {
        uuid id PK
        uuid job_opening_id FK
        uuid candidate_id FK
        string stage
        string status
        datetime applied_at
        datetime rejected_at
        datetime hired_at
        datetime created_at
        datetime updated_at
    }

    JOB_OPENING ||--o{ CANDIDATE_APPLICATION : receives
    CANDIDATE ||--o{ CANDIDATE_APPLICATION : applies
```

---

# 14. Notifications & Audit

```mermaid
erDiagram
    NOTIFICATION {
        uuid id PK
        uuid organization_id FK
        uuid user_id FK
        string type
        string title
        string message
        json data
        datetime read_at
        datetime created_at
    }

    AUDIT_LOG {
        uuid id PK
        uuid organization_id FK
        uuid actor_user_id FK
        string action
        string entity_type
        uuid entity_id
        json before_data
        json after_data
        string ip_address
        string user_agent
        datetime created_at
    }

    USER ||--o{ NOTIFICATION : receives
    USER ||--o{ AUDIT_LOG : performs
```

---

# 15. Recommended Core Indexes

## Employee

```text
INDEX(organization_id)
INDEX(organization_id, department_id)
UNIQUE(organization_id, employee_code)
```

## Attendance

```text
UNIQUE(employee_id, attendance_date)
INDEX(organization_id, attendance_date)
INDEX(employee_id, attendance_date DESC)
INDEX(organization_id, status, attendance_date)
```

## Leave

```text
INDEX(employee_id, status)
INDEX(organization_id, start_date, end_date)
UNIQUE(employee_id, leave_type_id, year) -- leave balance
```

## Approval

```text
INDEX(organization_id, status)
INDEX(approver_employee_id, status)
INDEX(target_type, target_id)
```

## Payroll

```text
UNIQUE(payroll_period_id, employee_id)
INDEX(organization_id, status)
```

---

# 16. Important Data Integrity Rules

1. Employee code is unique per organization.
2. User email uniqueness strategy must be explicitly chosen:
   - globally unique, or
   - unique within organization.
3. Attendance cannot belong to another organization's employee.
4. Leave request and leave type must belong to the same organization.
5. Approver must belong to the correct organization.
6. Payroll employee snapshot must belong to payroll period organization.
7. Finalized payroll records should be immutable except through controlled correction workflows.
8. Leave balance mutation must happen transactionally with approval.
9. Refresh token rotation must be transactional.
10. Audit records should be append-only.
