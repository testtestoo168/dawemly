<?php
/**
 * Dawemly API - Requests Endpoints (إجازات وأذونات)
 * POST /api/requests.php?action=leave
 * POST /api/requests.php?action=permission
 * GET  /api/requests.php?action=my
 * GET  /api/requests.php?action=pending  (admin)
 * GET  /api/requests.php?action=all      (admin)
 * POST /api/requests.php?action=update_status (admin)
 */

require_once __DIR__ . '/../core/bootstrap.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'leave': handleLeaveRequest(); break;
    case 'permission': handlePermissionRequest(); break;
    case 'my': handleMyRequests(); break;
    case 'pending': handlePendingRequests(); break;
    case 'all': handleAllRequests(); break;
    case 'update_status': handleUpdateStatus(); break;
    default: jsonError('Action not found', 404);
}

// ─── Create Leave Request ───
function handleLeaveRequest() {
    $user = requireAuth();
    $body = getBody();
    $pdo = getDB();

    $required = ['leave_type', 'start_date', 'end_date', 'reason'];
    foreach ($required as $field) {
        if (empty($body[$field])) jsonError("الحقل {$field} مطلوب");
    }

    $startDate = new DateTime($body['start_date']);
    $endDate = new DateTime($body['end_date']);
    $days = $endDate->diff($startDate)->days + 1;

    $stmt = $pdo->prepare("INSERT INTO requests (uid, emp_id, name, request_type, leave_type, start_date, end_date, days, reason, status, date_key) VALUES (?, ?, ?, 'إجازة', ?, ?, ?, ?, ?, 'تحت الإجراء', ?)");
    $stmt->execute([
        $user['uid'], $user['emp_id'], $user['name'],
        $body['leave_type'], $body['start_date'], $body['end_date'],
        $days, $body['reason'], date('Y-m-d')
    ]);

    jsonResponse(['success' => true, 'id' => $pdo->lastInsertId(), 'days' => $days]);
}

// ─── Create Permission Request ───
function handlePermissionRequest() {
    $user = requireAuth();
    $body = getBody();
    $pdo = getDB();

    $hours = 0;
    if (!empty($body['from_minutes']) && !empty($body['to_minutes'])) {
        $hours = ($body['to_minutes'] - $body['from_minutes']) / 60.0;
    }

    $stmt = $pdo->prepare("INSERT INTO requests (uid, emp_id, name, request_type, perm_type, from_time, to_time, date, reason, hours, status, date_key) VALUES (?, ?, ?, 'إذن', ?, ?, ?, ?, ?, ?, 'تحت الإجراء', ?)");
    $stmt->execute([
        $user['uid'], $user['emp_id'], $user['name'],
        $body['perm_type'] ?? '', $body['from_time'] ?? '', $body['to_time'] ?? '',
        $body['date'] ?? date('Y-m-d'), $body['reason'] ?? '',
        $hours, date('Y-m-d')
    ]);

    jsonResponse(['success' => true, 'id' => $pdo->lastInsertId(), 'hours' => $hours]);
}

// ─── Get My Requests ───
function handleMyRequests() {
    $user = requireAuth();
    $pdo = getDB();

    $stmt = $pdo->prepare("SELECT * FROM requests WHERE uid = ? ORDER BY created_at DESC");
    $stmt->execute([$user['uid']]);

    jsonResponse(['success' => true, 'requests' => $stmt->fetchAll()]);
}

// ─── Admin: Get Pending Requests ───
function handlePendingRequests() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $pdo = getDB();
    $stmt = $pdo->query("SELECT * FROM requests WHERE status = 'تحت الإجراء' ORDER BY created_at DESC");

    jsonResponse(['success' => true, 'requests' => $stmt->fetchAll()]);
}

// ─── Admin: Get All Requests ───
function handleAllRequests() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $pdo = getDB();
    $stmt = $pdo->query("SELECT * FROM requests ORDER BY created_at DESC LIMIT 500");

    jsonResponse(['success' => true, 'requests' => $stmt->fetchAll()]);
}

// ─── Admin: Update Request Status ───
function handleUpdateStatus() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $body = getBody();
    $requestId = $body['request_id'] ?? '';
    $newStatus = $body['status'] ?? '';

    if (empty($requestId) || empty($newStatus)) jsonError('الحقول مطلوبة');

    $pdo = getDB();
    $data = ['status' => $newStatus, 'reviewed_at' => date('Y-m-d H:i:s')];
    
    $sql = "UPDATE requests SET status = ?, reviewed_at = NOW()";
    $params = [$newStatus];

    if (!empty($body['admin_note'])) {
        $sql .= ", admin_note = ?";
        $params[] = $body['admin_note'];
    }

    $sql .= " WHERE id = ?";
    $params[] = $requestId;

    $pdo->prepare($sql)->execute($params);

    // Audit log
    $pdo->prepare("INSERT INTO audit_log (uid, user_name, action, details) VALUES (?, ?, 'update_request', ?)")
        ->execute([$user['uid'], $user['name'], "تحديث طلب #{$requestId} إلى {$newStatus}"]);

    jsonResponse(['success' => true]);
}
