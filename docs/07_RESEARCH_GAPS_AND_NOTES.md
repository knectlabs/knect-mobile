# Kerjancok — Research Gap Notes & Long-Term Backlog

> This file records important features discovered during the initial research phase that are not yet fully modeled or implemented.
>
> These items are **not forgotten features**. They are intentional long-term backlog items and should be considered when evolving the PRD, ERD, mobile flows, business rules, and permissions.

## 1. Design Reference

Primary design reference:

**Mekari Talenta**

Use Mekari Talenta as inspiration for:

- mobile employee dashboard
- attendance UX
- leave/overtime request flows
- approval flows
- payroll/payslip presentation
- HR admin dashboard
- employee management
- organization management
- reporting hierarchy

Do not create a pixel-perfect clone.

Kerjancok should have its own:

- visual identity
- typography
- spacing
- colors
- iconography
- component styling
- layout details
- product terminology where appropriate

The goal is:

> familiar HRIS UX, distinct Kerjancok product identity.

---

# 2. Initial Research References

## `qyupaww/flutter-hris`

Already covered:

- Flutter
- login
- dashboard
- GPS
- geofence
- selfie/photo verification
- attendance history
- profile
- feature-based architecture

Still missing or not explicit enough:

- map-focused attendance UX
- dev/staging/prod environment flavors
- skeleton/loading conventions
- stronger UI state conventions
- localization conventions

Recommended phase:
- mobile foundation / Phase 1

---

## Horilla HR Mobile

Already covered:

- punch in/out
- leave
- attendance correction
- approvals
- payroll/payslip
- notifications

Still missing or not explicit enough:

- break start/end tracking
- monthly hour account
- announcements/company feed
- people directory
- manager "My Team" dashboard
- leave holiday calendar
- leave allocation requests
- shift-change requests
- work-type requests
- expense claims
- asset requests
- biometric local unlock
- team leave clash warning
- undo-after-approval UX
- live team attendance view

Recommended phase:
- break tracking: Phase 1/2
- announcements: Phase 1/2
- My Team: Phase 1/2
- biometric unlock: Phase 2
- expense/assets: Phase 4
- leave clash warning: Phase 2

---

## `tyser1995/hris_app`

Already covered:

- multi-tenant architecture
- organization
- department
- position
- employees
- attendance
- scheduling
- leave
- payroll foundation
- notifications
- roles

Still missing or not explicit enough:

- employment types
- employee contracts
- employee documents
- dynamic permissions
- company branding
- employee-code generator
- user invite/management
- split shifts
- flexible shifts
- contract-expiry reports
- organization-specific settings
- access-management UI
- data-management settings
- super-admin organization management
- per-organization branding

Recommended phase:
- employment types: Phase 1
- contracts/documents: Phase 1/2
- dynamic permissions: Phase 2
- employee-code generator: Phase 1/2
- branding: Phase 2
- split/flexible shift: Phase 2
- contract expiry reporting: Phase 2

---

## SmartGeo HRIS

Already covered:

- server-side geofence
- selfie evidence
- overtime
- leave
- audit trail
- payroll architecture

Still missing or not explicit enough:

- configurable minimum leave notice such as H-3
- direct-camera/liveness-style attendance rule
- no-work-no-pay payroll rule
- configurable maximum overtime
- kasbon / employee loan
- max installment percentage rule, e.g. 30%
- force password change for new employees
- detailed BPJS rules
- detailed PPh21/tax rules
- explicit late deduction rules
- direct payroll PDF slip generation
- stricter anti-fraud attendance rules

Important:

SmartGeo's values must **not be hardcoded globally**.

Example:

```text
leave_min_notice_days = 3
weekday_overtime_max_minutes = 120
loan_installment_max_percent = 30
```

These should become configurable organization policies where appropriate.

Recommended phase:
- configurable leave/overtime rules: Phase 1/2
- force password change: Phase 1
- loans/kasbon: Phase 2/3
- detailed BPJS/PPh21: Phase 2+
- no-work-no-pay: Phase 2

---

# 3. Additional Missing Product Domains

The following items were discussed but are not yet fully represented in the current master ERD.

## 3.1 Attendance Breaks

Need:

```text
attendance_breaks
```

Purpose:

- break start
- break end
- duration
- monthly work-hour calculations

---

## 3.2 Timesheet

Need:

```text
projects
timesheet_entries
```

Purpose:

- task/project tracking
- start/end
- duration
- approval
- reporting

---

## 3.3 Holiday Calendar

Need:

```text
holiday_calendars
holidays
```

Purpose:

- leave day calculation
- attendance expectations
- payroll workday calculations
- shift planning

---

## 3.4 Employment Types

Need:

```text
employment_types
```

Examples:

- permanent
- contract
- probation
- internship
- part-time
- freelance

---

## 3.5 Employee Contracts

Need:

```text
employee_contracts
```

Purpose:

- contract period
- contract number
- contract status
- contract document
- expiry reminders

---

## 3.6 Employee Documents

Need:

```text
employee_documents
```

Examples:

- KTP
- NPWP
- contract
- certificate
- medical document
- other HR files

---

## 3.7 Dynamic Permissions

Current RBAC is role-oriented.

Long-term production model should support:

```text
roles
permissions
role_permissions
user_roles
```

Examples:

```text
employee.read
employee.write
attendance.override
leave.approve
payroll.read
payroll.run
payroll.finalize
```

---

## 3.8 Announcements

Need:

```text
announcements
announcement_reads
```

Different from notifications.

Announcement example:

> Company holiday announcement.

Notification example:

> Your leave request was approved.

---

## 3.9 Manager Team Dashboard

Mobile manager experience should include:

- checked in
- not checked in
- late
- on leave
- overtime
- pending approvals

Mostly API/query work, not necessarily a new core table.

---

## 3.10 Work Types

Need:

```text
work_types
work_type_requests
```

Examples:

- WFO
- WFH
- Hybrid
- Business Trip
- Field Work

---

## 3.11 Shift Change Requests

Need:

```text
shift_change_requests
```

Should reuse generic approval engine.

---

## 3.12 Expense Claims

Future:

```text
expense_claims
expense_claim_items
```

Recommended:
- Phase 4

---

## 3.13 Asset Requests / Asset Management

Future:

```text
assets
employee_assets
asset_requests
```

Recommended:
- Phase 4

---

## 3.14 Employee Code Generator

Need organization-level configuration such as:

```text
EMP-{YYYY}-{####}
```

Generation must be atomic.

Potential config:

```text
employee_code_pattern
employee_code_sequence
```

---

## 3.15 Company Branding

Potential organization fields/settings:

- logo
- primary color
- system title
- favicon
- email branding

Recommended:
- Phase 2

---

## 3.16 Employee Loans / Kasbon

Future:

```text
employee_loans
loan_installments
```

Rules must be configurable.

Example:

```text
max_installment_percent = 30
```

Do not hardcode Indonesian business assumptions globally.

---

## 3.17 Force Password Change

Add to user/session domain:

```text
must_change_password
password_changed_at
```

Suggested flow:

```text
Admin creates employee
→ temporary password
→ first login
→ forced password change
→ normal access
```

Recommended:
- Phase 1

---

## 3.18 Biometric Local Unlock

Mobile-only convenience/security layer:

- Face ID
- fingerprint

This does **not** replace backend authentication.

Flow:

```text
valid stored session
→ app reopened
→ biometric challenge
→ unlock local session
```

Recommended:
- Phase 2

---

## 3.19 Leave Clash Warning

Manager should receive context when leave overlaps with too many team members.

Example:

```text
3 employees in this team are already on leave.
```

Recommended:
- Phase 2

---

## 3.20 Attendance Source Methods

Explicit supported/future methods:

```text
MOBILE
WEB
RFID
BIOMETRIC
FINGERPRINT
MANUAL
IMPORT
```

Current attendance model is already capable of storing methods.

---

# 4. Talenta-Level Feature Coverage Notes

## Already represented

- GPS attendance
- server-side geofence
- selfie attendance
- suspicious attendance signals
- fake-location heuristics
- shifts
- leave
- sick leave via leave type
- overtime
- attendance correction
- multi-step approval
- payroll foundation
- payslip
- KPI/OKR
- performance review
- 360-review architecture
- recruitment foundation
- employee management
- organization
- notifications
- audit trail
- multi-company architecture

## Still backlog / incomplete

- timesheet
- break tracking
- holiday calendar
- announcements
- explicit people directory UX
- dynamic permission matrix
- employment contracts
- employee documents ERD
- WFH/work-type requests
- shift-change requests
- expense
- assets
- employee loans/kasbon
- employee-code generator
- company branding
- biometric unlock
- detailed salary disbursement
- detailed BPJS
- detailed PPh21
- succession planning
- individual development plan
- advanced onboarding
- advanced talent analytics

---

# 5. Implementation Rule

An AI coding agent must not interpret this backlog as permission to implement everything immediately.

Use phase priority.

If a feature is not part of the active development phase:

- preserve it in planning
- avoid architecture that blocks it
- do not build it prematurely

The objective is long-term consistency without over-engineering the MVP.
