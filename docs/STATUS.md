# Knect Mobile implementation status

Updated 2026-10-06 from current features, theme, and navigation.

## Implemented

Authentication, Home/shift status, employee directory/team activity/profile photos, attendance/history, leave/overtime/corrections, reimbursements, manager approvals, Inbox/FCM integration, payslips, performance goals/reviews, and announcements are available through the existing employee flows.

Profile-photo upload supplies the server face reference. Cloudinary image storage is accessed through API endpoints. Separate employee enrollment is absent from navigation.

Home shortcuts and Account menus use original SVG icons with neutral containers and contrasting theme colors. The original Knect violet palette and system light/dark mode are active. Requests uses a bottom-right floating plus action opening the existing category sheet.

## Attendance contract

Location/geofence comes first. Selfie is required when the resolved company face-verification setting requires it. Missing profile references block only that required flow. Outside-location policy determines rejection, pending approval with a note, or attendance with anomaly metadata. The API decides validity.

Clock In is unavailable after a recorded entry. Clock Out follows current attendance rules, including allowed early departure. Both are unavailable after a recorded exit. Pending attendance is not completed attendance and does not enter payroll before approval.

## Limits and verification

A physical phone must use a reachable LAN or HTTPS tunnel URL rather than phone localhost. Backend URL changes require restart/rebuild. Cloudinary secrets stay outside mobile configuration.

General PDF/Office upload, password reset, and a mobile recruitment console are not implemented. FCM needs platform/server credentials and iOS APNs setup.

Recent Flutter analyze and targeted widget checks passed for priority screens, 320/390 px layouts, enlarged text, theme behavior, clock-button availability, and protected profile-photo rendering. No new full regression, release APK, or physical Pixel GPS/camera acceptance is claimed. Android toolchain compatibility workarounds remain documented in the repository README.
