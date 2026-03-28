<?php
/**
 * Dawemly API - Users Management (Admin)
 * GET  /api/users.php?action=list
 * GET  /api/users.php?action=get&uid=xxx
 * POST /api/users.php?action=update
 * POST /api/users.php?action=toggle_active
 * POST /api/users.php?action=clear_session
 */

require_once __DIR__ . '/../core/bootstrap.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'list': handleList(); break;
    case 'get': handleGet(); break;
    case 'update': handleUpdate(); break;
    case 'toggle_active': handleToggleActive(); break;
    case 'clear_session': handleClearSession(); break;
    default: jsonError('Action not found', 404);
}

function handleList() {
    $user = requireAuth();
    $pdo = getDB();
    $stmt = $pdo->query("SELECT uid, email, phone, name, dept, role, emp_id, active, face_registered, face_photo_url, auth_override, auth_face, auth_biometric, auth_loc, multi_device_allowed, last_platform, last_device_model, last_login_at, created_at FROM users ORDER BY name ASC");
    jsonResponse(['success' => true, 'users' => $stmt->fetchAll()]);
}

function handleGet() {
    $user = requireAuth();
    $pdo = getDB();
    $uid = $_GET['uid'] ?? $user['uid'];
    $stmt = $pdo->prepare("SELECT uid, email, phone, name, dept, role, emp_id, active, face_registered, face_photo_url, auth_override, auth_face, auth_biometric, auth_loc, multi_device_allowed, fcm_token, last_platform, last_device_model, last_login_at, created_at FROM users WHERE uid = ?");
    $stmt->execute([$uid]);
    $u = $stmt->fetch();
    if (!$u) jsonError('مستخدم غير موجود', 404);
    jsonResponse(['success' => true, 'user' => $u]);
}

function handleUpdate() {
    $admin = requireAuth();
    if ($admin['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $uid = $body['uid'] ?? '';
    if (empty($uid)) jsonError('uid مطلوب');

    $pdo = getDB();
    $allowed = ['name','dept','role','phone','emp_id','active','auth_override','auth_face','auth_biometric','auth_loc','multi_device_allowed'];
    $sets = []; $params = [];
    foreach ($allowed as $field) {
        if (isset($body[$field])) {
            $col = $field;
            $sets[] = "{$col} = ?";
            $params[] = $body[$field];
        }
    }
    if (!empty($body['password'])) {
        $sets[] = "password = ?";
        $params[] = password_hash($body['password'], PASSWORD_DEFAULT);
    }
    if (empty($sets)) jsonError('لا توجد بيانات للتحديث');
    $params[] = $uid;
    $pdo->prepare("UPDATE users SET " . implode(', ', $sets) . " WHERE uid = ?")->execute($params);
    jsonResponse(['success' => true]);
}

function handleToggleActive() {
    $admin = requireAuth();
    if ($admin['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    $pdo->prepare("UPDATE users SET active = NOT active WHERE uid = ?")->execute([$body['uid'] ?? '']);
    jsonResponse(['success' => true]);
}

function handleClearSession() {
    $admin = requireAuth();
    if ($admin['role'] !== 'admin') jsonError('غير مصرح', 403);
    $body = getBody();
    $pdo = getDB();
    $pdo->prepare("DELETE FROM active_sessions WHERE uid = ?")->execute([$body['uid'] ?? '']);
    jsonResponse(['success' => true]);
}
