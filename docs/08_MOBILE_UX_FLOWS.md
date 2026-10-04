# Knect — Mobile UX Flow Notes

Primary UI reference: **Mekari Talenta**, visually differentiated.

Secondary interaction references:
- `qyupaww/flutter-hris`
- Horilla HR Mobile

## Design Principle

Use familiar HRIS patterns but do not copy pixel-for-pixel.

Knect should feel:
- modern
- clean
- enterprise-ready
- mobile-first
- simple for employees
- distinct from Talenta visually

## Main Employee Navigation

Recommended tabs:

```text
Home
Attendance
Requests
Payroll
Profile
```

Potential future:
- Team for manager role

## Home

Should show:

- greeting
- current date/time
- today's shift
- work status
- clock-in / clock-out CTA
- worked hours
- break status
- late status
- leave balance summary
- quick request
- announcement card
- notification badge

## Attendance

Flow:

```text
Open attendance
→ request/check location permission
→ obtain GPS
→ show map/current location
→ show office/geofence context
→ capture selfie
→ submit
→ backend validates
→ result screen
```

States:

- loading GPS
- permission denied
- GPS disabled
- low accuracy
- outside geofence
- camera denied
- upload failed
- success
- flagged/suspicious
- already clocked in

## Requests

Contains:

- leave
- overtime
- attendance correction
- future shift change
- future work type

## Payroll

- payroll periods
- payslip detail
- earnings
- deductions
- net salary

## Profile

- employee identity
- department
- position
- manager
- office
- employment type
- contract
- documents
- settings
- logout

## Manager Mode

Additional features:

- approval inbox
- My Team
- team attendance
- leave overlap warning
- pending requests
- team status

## Loading Convention

Every screen must define:

- initial loading
- pull-to-refresh/loading
- empty
- error
- content

Use skeleton loading where it improves perceived performance.

## Environments

Mobile should support:

- dev
- staging
- production

API base URL must never be hardcoded in UI code.
