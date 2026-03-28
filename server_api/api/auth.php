<?php
/**
 * Dawemly API - Auth Endpoints
 * POST /api/auth.php?action=login
 * POST /api/auth.php?action=register
 * POST /api/auth.php?action=logout
 * GET  /api/auth.php?action=me
 */

require_once __DIR__ . '/../core/bootstrap.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'login': handleLogin(); break;
    case 'register': handleRegister(); break;
    case 'logout': handleLogout(); break;
    case 'me': handleMe(); break;
    case 'reset_password': handleResetPassword(); break;
    case 'update_fcm': handleUpdateFCM(); break;
    default: jsonError('Action not found', 404);
}

// ─── Login ───
function handleLogin() {
    $body = getBody();
    $email = $body['email'] ?? '';
    $password = $body['password'] ?? '';
    $deviceInfo = $body['device_info'] ?? '';

    if (empty($email) || empty($password)) {
        jsonError('البريد الإلكتروني وكلمة المرور مطلوبين');
    }

    $pdo = getDB();

    // Find user
    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ? AND active = 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password'])) {
        jsonError('بيانات الدخول غير صحيحة');
    }

    // Check single device mode
    $settings = getSettings($pdo);
    $singleDevice = $settings['singleDeviceMode'] ?? false;

    if ($singleDevice && $user['role'] !== 'admin' && !$user['multi_device_allowed']) {
        $stmt = $pdo->prepare("SELECT id FROM active_sessions WHERE uid = ?");
        $stmt->execute([$user['uid']]);
        if ($stmt->fetch()) {
            jsonError('حسابك مفتوح على جهاز آخر. يجب تسجيل الخروج من الجهاز الأول أولاً.');
        }
    }

    // Generate token
    $token = generateToken();
    $stmt = $pdo->prepare("INSERT INTO api_tokens (uid, token, device_info, expires_at) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))");
    $stmt->execute([$user['uid'], $token, $deviceInfo]);

    // Register session
    $stmt = $pdo->prepare("REPLACE INTO active_sessions (uid, user_name, platform, device_model, os_version, device_brand, device_id) VALUES (?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([
        $user['uid'], $user['name'],
        $body['platform'] ?? 'mobile',
        $body['device_model'] ?? '',
        $body['os_version'] ?? '',
        $body['device_brand'] ?? '',
        $body['device_id'] ?? ''
    ]);

    // Update last login
    $pdo->prepare("UPDATE users SET last_login_at = NOW(), last_platform = ?, last_device_model = ?, last_os_version = ?, last_device_brand = ? WHERE uid = ?")
        ->execute([$body['platform'] ?? '', $body['device_model'] ?? '', $body['os_version'] ?? '', $body['device_brand'] ?? '', $user['uid']]);

    // Log audit
    logAudit($pdo, $user['uid'], $user['name'], 'login', 'تسجيل دخول');

    unset($user['password']);
    jsonResponse([
        'success' => true,
        'token' => $token,
        'user' => $user
    ]);
}

// ─── Register (Admin creates users) ───
function handleRegister() {
    $admin = requireAuth();
    if ($admin['role'] !== 'admin') jsonError('غير مصرح', 403);

    $body = getBody();
    $email = $body['email'] ?? '';
    $password = $body['password'] ?? '';
    $name = $body['name'] ?? '';

    if (empty($email) || empty($password) || empty($name)) {
        jsonError('جميع الحقول مطلوبة');
    }

    $pdo = getDB();

    // Check duplicate
    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$email]);
    if ($stmt->fetch()) jsonError('البريد الإلكتروني مستخدم بالفعل');

    $uid = generateUID();
    $empId = $body['emp_id'] ?? 'EMP-' . substr(time(), -6);

    $stmt = $pdo->prepare("INSERT INTO users (uid, email, password, name, dept, role, emp_id, phone, active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)");
    $stmt->execute([
        $uid, $email, password_hash($password, PASSWORD_DEFAULT),
        $name, $body['dept'] ?? '', $body['role'] ?? 'employee',
        $empId, $body['phone'] ?? ''
    ]);

    logAudit($pdo, $admin['uid'], $admin['name'], 'create_user', "إنشاء مستخدم: $name");

    jsonResponse([
        'success' => true,
        'uid' => $uid,
        'emp_id' => $empId
    ]);
}

// ─── Logout ───
function handleLogout() {
    $user = requireAuth();
    $pdo = getDB();

    // Clear session
    $pdo->prepare("DELETE FROM active_sessions WHERE uid = ?")->execute([$user['uid']]);

    // Remove token
    $headers = getallheaders();
    $auth = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    $token = substr($auth, 7);
    $pdo->prepare("DELETE FROM api_tokens WHERE token = ?")->execute([$token]);

    logAudit($pdo, $user['uid'], $user['name'], 'logout', 'تسجيل خروج');

    jsonResponse(['success' => true]);
}

// ─── Get current user ───
function handleMe() {
    $user = requireAuth();
    jsonResponse(['success' => true, 'user' => $user]);
}

// ─── Reset Password ───
function handleResetPassword() {
    $user = requireAuth();
    $body = getBody();
    $currentPass = $body['current_password'] ?? '';
    $newPass = $body['new_password'] ?? '';

    if (empty($currentPass) || empty($newPass)) jsonError('جميع الحقول مطلوبة');

    $pdo = getDB();
    $stmt = $pdo->prepare("SELECT password FROM users WHERE uid = ?");
    $stmt->execute([$user['uid']]);
    $row = $stmt->fetch();

    if (!password_verify($currentPass, $row['password'])) {
        jsonError('كلمة المرور الحالية غير صحيحة');
    }

    $pdo->prepare("UPDATE users SET password = ? WHERE uid = ?")
        ->execute([password_hash($newPass, PASSWORD_DEFAULT), $user['uid']]);

    jsonResponse(['success' => true]);
}

// ─── Update FCM Token ───
function handleUpdateFCM() {
    $user = requireAuth();
    $body = getBody();
    $fcmToken = $body['fcm_token'] ?? '';

    if (empty($fcmToken)) jsonError('FCM token مطلوب');

    $pdo = getDB();
    $pdo->prepare("UPDATE users SET fcm_token = ? WHERE uid = ?")
        ->execute([$fcmToken, $user['uid']]);

    jsonResponse(['success' => true]);
}

// ─── Helper: Get Settings ───
function getSettings($pdo) {
    $stmt = $pdo->prepare("SELECT setting_value FROM settings WHERE setting_key = 'general'");
    $stmt->execute();
    $row = $stmt->fetch();
    return $row ? json_decode($row['setting_value'], true) : [];
}

// ─── Helper: Log Audit ───
function logAudit($pdo, $uid, $name, $action, $details) {
    $ip = $_SERVER['REMOTE_ADDR'] ?? '';
    $pdo->prepare("INSERT INTO audit_log (uid, user_name, action, details, ip_address) VALUES (?, ?, ?, ?, ?)")
        ->execute([$uid, $name, $action, $details, $ip]);
}
