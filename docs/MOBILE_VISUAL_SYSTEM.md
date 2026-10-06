# Knect Mobile visual system

Updated 2026-10-06. The current design uses the original Knect violet palette and system light/dark mode, following the user's reversal of the earlier bright-only palette. Talenta is a hierarchy/interaction reference only; its branding, images, and colors are not copied.

## Theme and assets

- `lib/core/brand/brand.dart` owns the original brand palette and raster asset paths.
- `lib/core/theme/app_theme.dart` supplies `AppTheme.light` and `AppTheme.dark` to `main.dart` with `ThemeMode.system`.
- `lib/core/theme/knect_tokens.dart` contains compatible colors, spacing, radius, and typography tokens.
- `lib/shared/widgets/knect_feature_icon.dart` renders the original SVG feature icons in `assets/icons/` using theme `onSurface` contrast.
- `lib/shared/widgets/clock_action_buttons.dart` shares attendance buttons, SVG action icons, availability, and responsive layout.
- `lib/shared/widgets/profile_photo_avatar.dart` renders employee photos; missing/download/decode failures fall back to initials. Protected images follow the configured API host. Public HTTPS images use a separate client without session credentials.

## Current screens

Home uses greeting/photo/bell, a shift/attendance card, quick actions, announcements, and manager direct reports. Quick actions use neutral icon containers rather than purple-on-purple.

Inbox retains Notifications and Need My Approval with role restrictions and clear loading/empty/error states. Requests retains approval inbox/categories and uses a bottom-right floating plus to open the category sheet. Bottom list padding clears the floating action.

Account uses one SVG icon family and neutral containers, consistent separators, and a real profile picture when available. Announcement detail provides publication chip, title, author/date, and readable body.

Forms inherit central theme fields and surfaces. Attendance keeps schedule context, location/map then conditional selfie, and existing geofence/approval handling. Clock actions preserve the server-aligned availability rules.

Dark theme, brand headers, and camera scrims are intentional parts of the current implementation. Earlier forced-light screenshots and text are historical, not current design requirements.

## Verification

`flutter analyze` and targeted `test/mobile_visual_system_test.dart` / `test/employee_photo_test.dart` checks cover priority screens, navigation, request-sheet creation, 320/390 px widths, enlarged text, light/dark behavior, location/camera error states, employee-photo loading, and action availability. Optional screenshot capture uses `KNECT_CAPTURE_UI=1`; preview fonts use `KNECT_UI_FONT` and `KNECT_UI_ICON_FONT`.

These checks do not establish physical Pixel camera/GPS acceptance or a newly built release APK. No full regression is required for documentation-only edits.
