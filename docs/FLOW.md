# Knect Mobile employee flows

Updated 2026-10-06.

## Navigation

Login opens Home after session restore/sign-in. Main tabs are Home, Employees, Request, Inbox, and Account. Manager actions are role-restricted. The Requests bottom-right plus opens Leave, Overtime, or Attendance correction forms; reimbursement has its own Home action and feature screens.

## Attendance

1. Home or Live Attendance opens Clock In/Out with today's schedule.
2. Check location permission/service, obtain GPS, and show the map, office, distance, and radius.
3. Apply the company outside-location policy. Approval-required submissions need a note; blocked submissions cannot continue.
4. If face verification is required, require a valid profile reference and capture a selfie. Otherwise continue without a selfie.
5. Submit to the API, which validates clock windows, GPS, geofence, face match when required, duplicates, and anomalies.
6. Show recorded attendance or pending approval. Refresh today's state after completion.

Clock In is disabled after a recorded entry; Clock Out remains available under existing rules. After a recorded exit, both are disabled. Pending approval must not appear as a completed clock action.

## Other employee flows

- Profile photo upload calls the API to crop the face, store the protected image, and generate the employee reference. Employees do not enroll a separate face.
- Leave, overtime, correction, and reimbursement submission lead to request status, approval decisions, and notifications.
- Employees shows actual profile pictures where available, with initials only for missing/failed photos.
- Inbox opens notification targets or the authorized approval list. Announcements open a readable detail screen.
- Payslips and performance screens read their own backend domains; they do not calculate payroll or attendance validity on the phone.

The API remains authoritative. See [current status](STATUS.md) for unsupported flows and acceptance checks.
