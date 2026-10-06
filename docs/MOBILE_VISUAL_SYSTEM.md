# Knect Mobile visual system

Updated 2026-10-06. The user-approved bright white/lilac palette supersedes the former dark mobile palette in ADR-016. Talenta screenshots guide hierarchy and familiar interactions only; no reference branding or assets are copied.

## Theme and tokens

- lib/core/theme/knect_tokens.dart: KnectColors, KnectSpacing, KnectRadius, KnectTypography.
- lib/core/theme/app_theme.dart: KnectTheme.light centralizes app bars, surfaces, input fields, buttons, segmented controls, tabs, sheets, dialogs, chips, lists, navigation and typography.
- lib/main.dart: explicitly uses the light theme even when the device requests dark mode.
- BrandColors is a compatibility alias to shared tokens. The former dark gradient is removed.

User palette values are preserved. White labels on primary #8B5CF6 have 4.23:1 contrast, so filled actions use the specified strong primary #7C3AED (5.70:1). Secondary #6B7280 remains available for white surfaces; semantic muted text uses #606978 on lilac/background surfaces to meet 4.5:1. Status colors carry success/warning/error meaning, not arbitrary feature colors.

## Refined screens

Home: profile avatar, greeting and bell; white shift card with lilac heading; uniform shortcuts; announcements. Shortcuts reflow on narrow screens and enlarged text.
Inbox: lighter Notifications / Need My Approval tabs, existing role restrictions, white empty-state surface.
Requests: existing approval inbox and categories, pinned New request button, request selection sheet, existing forms/routes retained.
Forms: leave/overtime/correction and reimbursement share white surfaces, soft fields and consistent spacing. Existing validation, loading, submit and picker logic remain.
Account: outlined icons with one purple/lilac treatment, white rows and light separators.
Announcement detail: status/category chip derived from existing publication status, larger title, author/avatar/date and readable selectable body in a white card. No category data invented.
Attendance: bright location/selfie chrome, white schedule context, light permission/error states. Geofence, face requirements and submit logic remain unchanged.
Login, avatar fallbacks, status chips, notifications and approvals also use the shared tokens. Payroll, directory, performance and remaining routes inherit the central theme. The unreachable legacy face-enrollment component inherits the same tokens; it was not restored to employee navigation.

No legacy dark screen surfaces remain in lib. Camera image/scrim and small shadows retain dark colors for functional contrast. Existing brand raster/logo assets and launcher icon identity remain. Android launch background is light, including when the device uses dark mode.

## Verification

Only flutter analyze and test/mobile_visual_system_test.dart are used for mobile verification. The targeted tests exercise priority-screen navigation, request creation menus, announcement detail, location/camera error states and forced-light login. Optional KNECT_CAPTURE_UI=1 creates screenshots under .agents/tasks/mobile-visual-system; optional KNECT_UI_FONT and KNECT_UI_ICON_FONT load local preview fonts. No full regression suite is run. Widget compilation is verified; a new APK and physical Pixel camera flow are not verified by these checks.

Final result: six targeted checks passed (390 and 320 widths, 130% text scale, location/selfie error states, AA text/action contrast and light login on a dark-mode device). Flutter analyze passed. Android light launch resource XML is valid. No full regression, APK rebuild or physical-device acceptance was run.


## Current palette override (2026-10-06)

The user requested the original colors back. AppTheme and BrandColors now use the original violet palette and system light/dark mode. New surfaces follow ThemeData rather than fixed white backgrounds. Layout improvements and request navigation remain; Cloudinary is unchanged. The forced-light login check is replaced by a system-dark-mode check. Earlier bright-palette screenshots describe the prior revision.
