<?php
/**
 * Dawemly API - Attendance Endpoints
 * POST /api/attendance.php?action=checkIn
 * POST /api/attendance.php?action=checkOut
 * GET  /api/attendance.php?action=today
 * GET  /api/attendance.php?action=punches&date_key=YYYY-MM-DD
 * GET  /api/attendance.php?action=monthly&year=2026&month=3
 * GET  /api/attendance.php?action=all_today  (admin)
 * GET  /api/attendance.php?action=all_records (admin)
 */

require_once __DIR__ . '/../core/bootstrap.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'checkIn': handleCheckIn(); break;
    case 'checkOut': handleCheckOut(); break;
    case 'today': handleToday(); break;
    case 'punches': handlePunches(); break;
    case 'monthly': handleMonthly(); break;
    case 'all_today': handleAllToday(); break;
    case 'all_records': handleAllRecords(); break;
    default: jsonError('Action not found', 404);
}

// ─── Check In ───
function handleCheckIn() {
    $user = requireAuth();
    $body = getBody();
    $pdo = getDB();

    $now = new DateTime();
    $dateKey = $now->format('Y-m-d');

    // Save punch
    $stmt = $pdo->prepare("INSERT INTO attendance (uid, emp_id, name, type, local_time, date_key, lat, lng, accuracy, biometric, auth_method, face_photo_url) VALUES (?, ?, ?, 'checkIn', NOW(), ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([
        $user['uid'], $user['emp_id'], $user['name'], $dateKey,
        $body['lat'] ?? null, $body['lng'] ?? null, $body['accuracy'] ?? null,
        $body['biometric'] ?? 0, $body['auth_method'] ?? 'fingerprint',
        $body['face_photo_url'] ?? null
    ]);

    // Update daily summary
    $stmt = $pdo->prepare("SELECT id FROM attendance_daily WHERE uid = ? AND date_key = ?");
    $stmt->execute([$user['uid'], $dateKey]);
    $existing = $stmt->fetch();

    if (!$existing) {
        $pdo->prepare("INSERT INTO attendance_daily (uid, emp_id, name, date_key, first_check_in, first_check_in_lat, first_check_in_lng, check_in, check_in_lat, check_in_lng, sessions, current_session_start, is_checked_in, status) VALUES (?, ?, ?, ?, NOW(), ?, ?, NOW(), ?, ?, 1, NOW(), 1, 'حاضر')")
            ->execute([$user['uid'], $user['emp_id'], $user['name'], $dateKey, $body['lat'] ?? null, $body['lng'] ?? null, $body['lat'] ?? null, $body['lng'] ?? null]);
    } else {
        $pdo->prepare("UPDATE attendance_daily SET current_session_start = NOW(), is_checked_in = 1, sessions = sessions + 1, status = 'حاضر' WHERE uid = ? AND date_key = ?")
            ->execute([$user['uid'], $dateKey]);
    }

    $hour = (int)$now->format('G');
    $minute = $now->format('i');
    $period = $hour >= 12 ? 'م' : 'ص';
    $h12 = $hour > 12 ? $hour - 12 : ($hour == 0 ? 12 : $hour);

    jsonResponse([
        'success' => true,
        'time' => "{$h12}:{$minute} {$period}",
        'lat' => $body['lat'] ?? null,
        'lng' => $body['lng'] ?? null
    ]);
}

// ─── Check Out ───
function handleCheckOut() {
    $user = requireAuth();
    $body = getBody();
    $pdo = getDB();

    $now = new DateTime();
    $dateKey = $now->format('Y-m-d');

    // Save punch
    $stmt = $pdo->prepare("INSERT INTO attendance (uid, emp_id, name, type, local_time, date_key, lat, lng, accuracy, biometric, auth_method, face_photo_url) VALUES (?, ?, ?, 'checkOut', NOW(), ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([
        $user['uid'], $user['emp_id'], $user['name'], $dateKey,
        $body['lat'] ?? null, $body['lng'] ?? null, $body['accuracy'] ?? null,
        $body['biometric'] ?? 0, $body['auth_method'] ?? 'fingerprint',
        $body['face_photo_url'] ?? null
    ]);

    // Calculate session minutes
    $sessionMinutes = 0;
    $stmt = $pdo->prepare("SELECT current_session_start FROM attendance_daily WHERE uid = ? AND date_key = ?");
    $stmt->execute([$user['uid'], $dateKey]);
    $daily = $stmt->fetch();

    if ($daily && $daily['current_session_start']) {
        $start = new DateTime($daily['current_session_start']);
        $diff = $now->getTimestamp() - $start->getTimestamp();
        $sessionMinutes = max(0, intval($diff / 60));
    }

    // Update daily summary
    $pdo->prepare("UPDATE attendance_daily SET last_check_out = NOW(), last_check_out_lat = ?, last_check_out_lng = ?, check_out = NOW(), check_out_lat = ?, check_out_lng = ?, total_worked_minutes = total_worked_minutes + ?, is_checked_in = 0, status = 'مكتمل' WHERE uid = ? AND date_key = ?")
        ->execute([$body['lat'] ?? null, $body['lng'] ?? null, $body['lat'] ?? null, $body['lng'] ?? null, $sessionMinutes, $user['uid'], $dateKey]);

    $hour = (int)$now->format('G');
    $minute = $now->format('i');
    $period = $hour >= 12 ? 'م' : 'ص';
    $h12 = $hour > 12 ? $hour - 12 : ($hour == 0 ? 12 : $hour);

    jsonResponse([
        'success' => true,
        'time' => "{$h12}:{$minute} {$period}",
        'lat' => $body['lat'] ?? null,
        'lng' => $body['lng'] ?? null
    ]);
}

// ─── Get today's record ───
function handleToday() {
    $user = requireAuth();
    $pdo = getDB();
    $dateKey = date('Y-m-d');

    $stmt = $pdo->prepare("SELECT * FROM attendance_daily WHERE uid = ? AND date_key = ?");
    $stmt->execute([$user['uid'], $dateKey]);
    $record = $stmt->fetch();

    jsonResponse(['success' => true, 'record' => $record]);
}

// ─── Get day punches ───
function handlePunches() {
    $user = requireAuth();
    $pdo = getDB();
    $dateKey = $_GET['date_key'] ?? date('Y-m-d');

    $stmt = $pdo->prepare("SELECT * FROM attendance WHERE uid = ? AND date_key = ? ORDER BY local_time ASC");
    $stmt->execute([$user['uid'], $dateKey]);
    $punches = $stmt->fetchAll();

    jsonResponse(['success' => true, 'punches' => $punches]);
}

// ─── Get monthly records ───
function handleMonthly() {
    $user = requireAuth();
    $pdo = getDB();
    $year = $_GET['year'] ?? date('Y');
    $month = str_pad($_GET['month'] ?? date('m'), 2, '0', STR_PAD_LEFT);

    $stmt = $pdo->prepare("SELECT * FROM attendance_daily WHERE uid = ? AND date_key LIKE ?");
    $stmt->execute([$user['uid'], "{$year}-{$month}%"]);
    $records = $stmt->fetchAll();

    jsonResponse(['success' => true, 'records' => $records]);
}

// ─── Admin: Get all today's records ───
function handleAllToday() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $pdo = getDB();
    $dateKey = date('Y-m-d');

    $stmt = $pdo->prepare("SELECT * FROM attendance_daily WHERE date_key = ?");
    $stmt->execute([$dateKey]);
    $records = $stmt->fetchAll();

    jsonResponse(['success' => true, 'records' => $records]);
}

// ─── Admin: Get all records ───
function handleAllRecords() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $pdo = getDB();
    $limit = min(intval($_GET['limit'] ?? 500), 1000);
    $offset = intval($_GET['offset'] ?? 0);

    $stmt = $pdo->prepare("SELECT * FROM attendance_daily ORDER BY date_key DESC, name ASC LIMIT ? OFFSET ?");
    $stmt->execute([$limit, $offset]);
    $records = $stmt->fetchAll();

    jsonResponse(['success' => true, 'records' => $records]);
}
