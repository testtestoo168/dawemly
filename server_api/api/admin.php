<?php
/**
 * Dawemly API - Settings, Locations, Schedules, Holidays, Notifications
 * GET/POST /api/admin.php?action=...
 */

require_once __DIR__ . '/../core/bootstrap.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    // Settings
    case 'get_settings': getSettings_(); break;
    case 'save_settings': saveSettings(); break;
    // Locations
    case 'get_locations': getLocations(); break;
    case 'save_location': saveLocation(); break;
    case 'delete_location': deleteLocation(); break;
    // Schedules
    case 'get_schedules': getSchedules(); break;
    case 'save_schedule': saveSchedule(); break;
    case 'delete_schedule': deleteSchedule(); break;
    // Holidays
    case 'get_holidays': getHolidays(); break;
    case 'save_holiday': saveHoliday(); break;
    case 'delete_holiday': deleteHoliday(); break;
    // Notifications
    case 'get_notifications': getNotifications(); break;
    case 'mark_read': markRead(); break;
    case 'send_notification': sendNotification(); break;
    // Verification Requests
    case 'send_verification': sendVerification(); break;
    case 'get_verifications': getVerifications(); break;
    case 'respond_verification': respondVerification(); break;
    // Audit
    case 'get_audit_log': getAuditLog(); break;
    // Active Sessions
    case 'get_sessions': getSessions(); break;
    // Upload
    case 'upload': handleUpload(); break;
    default: jsonError('Action not found', 404);
}

// ═══ SETTINGS ═══
function getSettings_() {
    $user = requireAuth();
    $pdo = getDB();
    $stmt = $pdo->query("SELECT setting_key, setting_value FROM settings");
    $settings = [];
    foreach ($stmt->fetchAll() as $row) {
        $settings[$row['setting_key']] = json_decode($row['setting_value'], true);
    }
    jsonResponse(['success' => true, 'settings' => $settings]);
}

function saveSettings() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    $key = $body['key'] ?? 'general';
    $value = json_encode($body['value'] ?? $body, JSON_UNESCAPED_UNICODE);
    $pdo->prepare("INSERT INTO settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = ?")->execute([$key, $value, $value]);
    jsonResponse(['success' => true]);
}

// ═══ LOCATIONS ═══
function getLocations() {
    requireAuth();
    $pdo = getDB();
    $stmt = $pdo->query("SELECT * FROM locations ORDER BY name ASC");
    jsonResponse(['success' => true, 'locations' => $stmt->fetchAll()]);
}

function saveLocation() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    if (!empty($body['id'])) {
        $pdo->prepare("UPDATE locations SET name=?, lat=?, lng=?, radius=?, active=?, assigned_employees=? WHERE id=?")->execute([$body['name'], $body['lat'], $body['lng'], $body['radius'] ?? 200, $body['active'] ?? 1, json_encode($body['assigned_employees'] ?? []), $body['id']]);
    } else {
        $pdo->prepare("INSERT INTO locations (name, lat, lng, radius, active, assigned_employees) VALUES (?,?,?,?,?,?)")->execute([$body['name'], $body['lat'], $body['lng'], $body['radius'] ?? 200, $body['active'] ?? 1, json_encode($body['assigned_employees'] ?? [])]);
    }
    jsonResponse(['success' => true]);
}

function deleteLocation() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    $pdo->prepare("DELETE FROM locations WHERE id = ?")->execute([$body['id'] ?? 0]);
    jsonResponse(['success' => true]);
}

// ═══ SCHEDULES ═══
function getSchedules() {
    requireAuth();
    $pdo = getDB();
    $stmt = $pdo->query("SELECT * FROM schedules ORDER BY id ASC");
    $schedules = $stmt->fetchAll();
    foreach ($schedules as &$s) {
        $s['days'] = json_decode($s['days'], true) ?? [];
        $s['emp_ids'] = json_decode($s['emp_ids'], true) ?? [];
    }
    jsonResponse(['success' => true, 'schedules' => $schedules]);
}

function saveSchedule() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    if (!empty($body['id'])) {
        $pdo->prepare("UPDATE schedules SET name=?, shift_id=?, days=?, emp_ids=? WHERE id=?")->execute([$body['name'], $body['shift_id'] ?? 1, json_encode($body['days'] ?? []), json_encode($body['emp_ids'] ?? []), $body['id']]);
    } else {
        $pdo->prepare("INSERT INTO schedules (name, shift_id, days, emp_ids) VALUES (?,?,?,?)")->execute([$body['name'], $body['shift_id'] ?? 1, json_encode($body['days'] ?? []), json_encode($body['emp_ids'] ?? [])]);
    }
    jsonResponse(['success' => true]);
}

function deleteSchedule() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    $pdo->prepare("DELETE FROM schedules WHERE id = ?")->execute([$body['id'] ?? 0]);
    jsonResponse(['success' => true]);
}

// ═══ HOLIDAYS ═══
function getHolidays() {
    requireAuth();
    $pdo = getDB();
    $stmt = $pdo->query("SELECT * FROM holidays ORDER BY id ASC");
    $holidays = $stmt->fetchAll();
    foreach ($holidays as &$h) { $h['emp_ids'] = json_decode($h['emp_ids'], true) ?? []; }
    jsonResponse(['success' => true, 'holidays' => $holidays]);
}

function saveHoliday() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    if (!empty($body['id'])) {
        $pdo->prepare("UPDATE holidays SET name=?, date=?, days=?, type=?, emp_ids=? WHERE id=?")->execute([$body['name'], $body['date'], $body['days'] ?? 1, $body['type'] ?? 'عامة', json_encode($body['emp_ids'] ?? []), $body['id']]);
    } else {
        $pdo->prepare("INSERT INTO holidays (name, date, days, type, emp_ids) VALUES (?,?,?,?,?)")->execute([$body['name'], $body['date'], $body['days'] ?? 1, $body['type'] ?? 'عامة', json_encode($body['emp_ids'] ?? [])]);
    }
    jsonResponse(['success' => true]);
}

function deleteHoliday() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    $pdo->prepare("DELETE FROM holidays WHERE id = ?")->execute([$body['id'] ?? 0]);
    jsonResponse(['success' => true]);
}

// ═══ NOTIFICATIONS ═══
function getNotifications() {
    $user = requireAuth();
    $pdo = getDB();
    $stmt = $pdo->prepare("SELECT * FROM notifications WHERE uid = ? ORDER BY timestamp DESC LIMIT 100");
    $stmt->execute([$user['uid']]);
    jsonResponse(['success' => true, 'notifications' => $stmt->fetchAll()]);
}

function markRead() {
    $user = requireAuth();
    $body = getBody();
    $pdo = getDB();
    if (!empty($body['id'])) {
        $pdo->prepare("UPDATE notifications SET is_read = 1 WHERE id = ? AND uid = ?")->execute([$body['id'], $user['uid']]);
    } else {
        $pdo->prepare("UPDATE notifications SET is_read = 1 WHERE uid = ?")->execute([$user['uid']]);
    }
    jsonResponse(['success' => true]);
}

function sendNotification() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    $uid = $body['uid'] ?? '';
    $pdo->prepare("INSERT INTO notifications (uid, title, body, type, batch_id) VALUES (?,?,?,?,?)")
        ->execute([$uid, $body['title'] ?? 'داوملي', $body['body'] ?? '', $body['type'] ?? 'general', $body['batch_id'] ?? null]);

    // Queue FCM if token exists
    $stmt = $pdo->prepare("SELECT fcm_token FROM users WHERE uid = ?");
    $stmt->execute([$uid]);
    $u = $stmt->fetch();
    if ($u && !empty($u['fcm_token'])) {
        $pdo->prepare("INSERT INTO fcm_queue (token, title, body) VALUES (?,?,?)")
            ->execute([$u['fcm_token'], $body['title'] ?? 'داوملي', $body['body'] ?? '']);
    }
    jsonResponse(['success' => true]);
}

// ═══ VERIFICATION REQUESTS ═══
function sendVerification() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    $batchId = bin2hex(random_bytes(8));
    $employees = $body['employees'] ?? [];

    foreach ($employees as $emp) {
        $pdo->prepare("INSERT INTO verification_requests (batch_id, uid, emp_id, emp_name, status, sent_by) VALUES (?,?,?,?,'pending',?)")
            ->execute([$batchId, $emp['uid'], $emp['emp_id'] ?? '', $emp['name'] ?? '', $user['name']]);
        // Send notification
        $pdo->prepare("INSERT INTO notifications (uid, title, body, type, batch_id) VALUES (?,?,?,?,?)")
            ->execute([$emp['uid'], 'طلب إثبات حالة', 'يرجى إثبات تواجدك في نطاق العمل الآن', 'verify_request', $batchId]);
    }
    jsonResponse(['success' => true, 'batch_id' => $batchId]);
}

function getVerifications() {
    $user = requireAuth();
    $pdo = getDB();
    $stmt = $pdo->query("SELECT * FROM verification_requests ORDER BY sent_at DESC LIMIT 100");
    jsonResponse(['success' => true, 'verifications' => $stmt->fetchAll()]);
}

function respondVerification() {
    $user = requireAuth();
    $body = getBody();
    $pdo = getDB();
    $pdo->prepare("UPDATE verification_requests SET status='responded', responded_at=NOW(), emp_lat=?, emp_lng=?, in_range=?, distance=? WHERE id=? AND uid=?")
        ->execute([$body['lat'] ?? null, $body['lng'] ?? null, $body['in_range'] ?? null, $body['distance'] ?? null, $body['id'] ?? 0, $user['uid']]);
    jsonResponse(['success' => true]);
}

// ═══ AUDIT LOG ═══
function getAuditLog() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $pdo = getDB();
    $limit = min(intval($_GET['limit'] ?? 200), 500);
    $stmt = $pdo->prepare("SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT ?");
    $stmt->execute([$limit]);
    jsonResponse(['success' => true, 'logs' => $stmt->fetchAll()]);
}

// ═══ ACTIVE SESSIONS ═══
function getSessions() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);
    $pdo = getDB();
    $stmt = $pdo->query("SELECT s.*, u.name, u.email, u.emp_id FROM active_sessions s JOIN users u ON s.uid = u.uid ORDER BY s.login_at DESC");
    jsonResponse(['success' => true, 'sessions' => $stmt->fetchAll()]);
}

// ═══ FILE UPLOAD (Face photos) ═══
function handleUpload() {
    $user = requireAuth();
    if (!isset($_FILES['file'])) jsonError('لا يوجد ملف');

    $file = $_FILES['file'];
    $uploadDir = __DIR__ . '/../uploads/faces/' . $user['uid'] . '/';
    if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);

    $ext = pathinfo($file['name'], PATHINFO_EXTENSION) ?: 'jpg';
    $filename = time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
    $filepath = $uploadDir . $filename;

    if (!move_uploaded_file($file['tmp_name'], $filepath)) {
        jsonError('فشل رفع الملف');
    }

    $baseUrl = rtrim(env('APP_URL', ''), '/');
    $url = "{$baseUrl}/attendance/api/uploads/faces/{$user['uid']}/{$filename}";

    jsonResponse(['success' => true, 'url' => $url, 'path' => $filepath]);
}
