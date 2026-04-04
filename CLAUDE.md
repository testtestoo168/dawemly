# Dawemly — نظام إدارة الحضور والانصراف

> **مهم: اقرأ `.claude/STATUS.md` أولاً — فيه آخر تحديث وايش محتاج يتعمل**

## Project Structure
- **Flutter app**: `/var/www/attendance/lib/` (screens/admin, screens/employee, services, theme)
- **PHP API**: `/var/www/attendance/api/api/` (admin.php, attendance.php, auth.php, face.php, salary.php, leaves.php, requests.php, users.php, superadmin.php)
- **Bootstrap**: `/var/www/attendance/api/core/bootstrap.php`
- **Cron jobs**: `/var/www/attendance/api/cron/` (auto_checkout.php, notify_late.php)
- **Web deploy**: `/var/www/attendance/app/` (Flutter web build)
- **DB**: MySQL `dawemly`, user=root, pass=Ahmed@2026!

## Architecture
- Admin screens use `W` colors (adaptive: web=AC, mobile=C) from `lib/theme/app_colors.dart`
- Employee screens use `C` colors
- Admin app: `admin_app.dart` has sidebar (web) + bottom nav with "المزيد" (mobile)
- Multi-tenant: each org gets separate DB `dawemly_org_{id}` via `getOrgDB()` in bootstrap
- FCM push notifications via Firebase service account
- Face recognition: ML Kit + server-side comparison

## Credentials
- Admin: admin@dawemly.com / Admin@2026
- Employee: ahmed@dawmly.sa / Ahmed@2026
- Super Admin: super@dawemly.com / Super@2026
- API: http://187.124.177.100/attendance/api/
- Web: http://187.124.177.100/attendance/app/

## Git
- Main repo: github.com/testtestoo168/dawemly (branch: claude/verify-fingerprint-app-qyR8t)
- API repo: github.com/testtestoo168/dawemly-api (branch: main)

## Key Rules
- Mobile-first design (375px width)
- NO text truncation on names (no TextOverflow.ellipsis on names)
- RTL Arabic layout
- Page titles in AppBar only (not duplicated inside page)
- Text inputs for numbers (not sliders)
- fl_chart for dashboard charts
- Always clear active_sessions before testing login:
  `mysql -u root -p'Ahmed@2026!' dawemly -e "DELETE FROM active_sessions"`

## Features Done
- Fingerprint + Face + GPS attendance
- Late/early auto-calculation from schedules
- Multi-session check-in/out
- Admin: dashboard (with charts), employees, user mgmt, roles, verify, overtime, schedules, requests, reports, notifications, audit, settings, salary
- Employee: home, attendance history, leave/permission requests, locations (map+geofence), schedule, profile, face registration
- Leave balance (admin settings tab + employee card)
- Auto-checkout cron (11:59 PM daily)
- Multi-tenant (separate DBs per org)
- FCM push notifications
- Responsive UI (mobile + web)

## Still TODO
- Super admin Flutter screen (API ready)
- Absence report (who didn't show up)
- Break tracking
- Employee photo/avatar
- Weekly summary notifications
- Kiosk mode
- Onboarding screens
- Dark mode toggle
- Multi-language (English)
