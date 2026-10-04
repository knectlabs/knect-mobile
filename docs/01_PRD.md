# Knect — Product Requirements Document

## Document Status

Version: `1.0`

Status: Active planning source of truth.

---

# 1. Problem Statement

Many companies need a unified system for employee data, attendance, leave, overtime, payroll, approvals, and HR operations.

Common problems:

- employee information spread across spreadsheets
- attendance systems disconnected from payroll
- manual leave approvals
- unclear attendance corrections
- difficult shift management
- weak audit trails
- payroll calculation errors
- HR reporting requires manual consolidation
- employee self-service is limited

Knect aims to centralize these workflows in one HRIS.

---

# 2. Product Goals

## Primary Goals

1. Provide reliable employee master data.
2. Make attendance easy for employees and verifiable for HR.
3. Automate leave and overtime workflows.
4. Provide reusable approval workflows.
5. Reduce manual payroll preparation.
6. Provide employee self-service through mobile.
7. Provide HR operations through an admin dashboard.
8. Preserve auditability of sensitive actions.

## Secondary Goals

- analytics
- performance management
- recruitment
- onboarding
- integration ecosystem

---

# 3. Non-Goals for MVP

Phase 1 does not require:

- advanced Indonesian tax automation
- full BPJS automation
- AI/ML attendance fraud models
- accounting integration
- full applicant tracking system
- advanced talent succession
- enterprise SSO
- on-prem deployment
- complex payroll formulas for every Indonesian company

---

# 4. User Personas

## Employee

Needs:
- clock in/out
- see today's shift
- see attendance status
- request leave
- request overtime
- request attendance correction
- see leave balance
- see payslip
- receive HR announcements

## Manager

Needs:
- see team
- see team attendance
- approve/reject requests
- review employee performance
- identify absence/late patterns

## HR

Needs:
- manage employee lifecycle
- configure attendance
- configure leave
- manage payroll
- investigate attendance anomalies
- run reports
- operate recruitment

## Company Admin

Needs:
- configure organization
- manage access
- manage company-level settings
- see cross-company operational reports

---

# 5. Functional Requirements

## 5.1 Authentication

### Requirements

- email/password login
- access token
- refresh token
- logout
- logout from one device
- logout from all devices
- token rotation
- forgot password
- reset password
- account activation/deactivation

### Acceptance

Expired access token can be renewed with a valid refresh token.

Reused or revoked refresh token must fail.

---

## 5.2 Organization

Company can manage:

- company identity
- timezone
- address
- organization status
- departments
- positions
- reporting lines

Employees belong to one organization in initial implementation.

---

## 5.3 Employee Management

Employee profile includes:

- employee ID/NIK internal
- full name
- email
- phone
- employment status
- join date
- termination date
- department
- position
- manager
- office
- profile photo
- emergency contact
- employee documents

Future extensions:

- bank
- tax
- BPJS
- family
- education

---

## 5.4 Office & Geofence

Office contains:

- name
- address
- latitude
- longitude
- allowed radius
- timezone
- active status

Attendance geofence is evaluated server-side.

The mobile application sends raw coordinates and GPS accuracy.

---

## 5.5 Shift Management

Shift contains:

- name
- start time
- end time
- break configuration
- grace period
- clock-in window
- clock-out window
- cross-midnight indicator

Employee schedule assigns a shift for a date range.

Future:

- rotating schedule
- flexible schedule
- split shift

---

## 5.6 Attendance

Employee can:

- clock in
- clock out
- see today's attendance
- see attendance history

Clock-in data may include:

- latitude
- longitude
- GPS accuracy
- selfie
- device
- timestamp
- optional note

System calculates:

- distance from office
- geofence validity
- attendance status
- late minutes
- early leave minutes
- work duration
- overtime candidate duration

### Status Examples

- PRESENT
- LATE
- ABSENT
- LEAVE
- SICK
- OFF_DAY
- HOLIDAY

Attendance correction must be modeled as a request, not silent direct mutation by employee.

---

## 5.7 Attendance Evidence

Evidence can contain:

- selfie
- supporting attachment
- device metadata

Evidence is stored separately from the main attendance row.

Reason:

- avoid oversized attendance rows
- preserve evidence lifecycle
- support multiple evidence items

---

## 5.8 Attendance Anomaly

An anomaly record represents an automated risk signal.

Examples:

- OUTSIDE_GEOFENCE
- LOW_GPS_ACCURACY
- MOCK_LOCATION
- IMPOSSIBLE_TRAVEL
- DUPLICATE_ATTEMPT
- UNKNOWN_DEVICE

An anomaly does not automatically mean fraud.

It is a review signal.

---

## 5.9 Leave

HR configures leave types.

Examples:

- annual leave
- sick leave
- unpaid leave
- special leave

Leave type can define:

- yearly quota
- paid/unpaid
- proof required
- minimum request notice
- approval workflow

Employee can:

- see balance
- submit request
- cancel pending request
- see request status

---

## 5.10 Overtime

Employee can request overtime.

Request includes:

- date
- start time
- end time
- reason
- calculated duration

Manager/HR can approve or reject.

Approved overtime becomes eligible for payroll aggregation.

---

## 5.11 Approval Engine

Approval must be reusable.

It should support:

- leave
- overtime
- attendance correction
- future expense claims
- future shift requests

Approval Request:
- target type
- target ID
- requester
- current step
- status

Approval Step:
- sequence
- approver
- action
- comment
- acted timestamp

---

## 5.12 Payroll

### Phase 2

Payroll period contains:

- name
- start date
- end date
- status

Per employee payroll snapshot contains:

- basic salary
- allowances
- overtime
- deductions
- gross salary
- net salary

Payroll lines contain individual components.

Examples:

- BASIC_SALARY
- POSITION_ALLOWANCE
- MEAL_ALLOWANCE
- OVERTIME
- LATE_DEDUCTION
- LOAN_INSTALLMENT
- TAX
- BPJS

Payroll records must be snapshots.

Historical payroll must not change when current employee salary settings change.

---

## 5.13 Payslip

Employee can view payslip for a finalized payroll period.

Payslip may later be exported as PDF.

Sensitive payroll data requires strict authorization.

---

## 5.14 Performance

### Phase 3

Features:

- goals
- KPI
- OKR
- performance review cycles
- self review
- manager review
- peer review
- 360 review

A performance goal can contain:

- title
- description
- target
- progress
- weight
- date range
- status

---

## 5.15 Recruitment

### Phase 4

Features:

- job openings
- candidates
- applications
- recruitment stages
- interviews
- offers
- conversion to employee

Applicant records must remain separate from employees until hired.

---

## 5.16 Notifications

Channels:

- in-app
- push
- email later

Events:

- leave submitted
- leave approved/rejected
- overtime submitted
- attendance anomaly
- payslip published
- review requested
- announcement

---

## 5.17 Audit Log

Sensitive actions must generate audit logs.

Examples:

- employee salary edited
- employee terminated
- attendance overridden
- payroll finalized
- role changed
- leave balance manually adjusted

Audit should capture:

- actor
- action
- entity
- entity ID
- old value where appropriate
- new value where appropriate
- IP
- user agent
- timestamp

---

# 6. Mobile Navigation

Recommended:

- Home
- Attendance
- Requests
- Payroll
- Profile

Home:

- current date/time
- employee greeting
- shift today
- clock in/out
- attendance state
- quick leave request
- announcements

---

# 7. Admin Navigation

Recommended:

- Dashboard
- Employees
- Organization
- Attendance
- Schedule & Shifts
- Leave
- Overtime
- Approvals
- Payroll
- Performance
- Recruitment
- Reports
- Settings

---

# 8. Reporting

Phase 1 basic reports:

- daily attendance
- monthly attendance
- late employees
- absence
- leave usage
- overtime
- headcount

Later:

- payroll cost
- turnover
- department attendance
- workforce analytics

---

# 9. Non-Functional Requirements

## Performance

Common list endpoints should target acceptable interactive latency under normal SaaS workloads.

Use pagination.

Avoid unbounded employee or attendance queries.

## Reliability

Critical operations should use database transactions:

- payroll finalization
- leave approval affecting balance
- refresh-token rotation
- attendance correction

## Security

See `00_AI_PROJECT_CONTEXT.md`.

## Scalability

Architecture should support many organizations without creating one database per customer.

---

# 10. MVP Exit Criteria

MVP is considered complete when:

1. HR can create organization structure.
2. HR can create employees.
3. HR can configure offices and shifts.
4. Employee can login on mobile.
5. Employee can clock in/out using GPS and selfie.
6. Server validates geofence.
7. Attendance history is available.
8. Employee can submit leave.
9. Manager can approve leave.
10. Employee can submit overtime.
11. Manager can approve overtime.
12. HR can view attendance and requests in admin.
13. Important changes are auditable.
