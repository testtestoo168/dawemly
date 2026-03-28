<?php
/**
 * Dawemly API - Face Recognition
 * POST /api/face.php?action=register
 * POST /api/face.php?action=verify
 * GET  /api/face.php?action=status
 * GET  /api/face.php?action=history
 * POST /api/face.php?action=reset (admin)
 */

require_once __DIR__ . '/../core/bootstrap.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'register': handleRegister(); break;
    case 'verify': handleVerify(); break;
    case 'status': handleStatus(); break;
    case 'history': handleHistory(); break;
    case 'reset': handleReset(); break;
    default: jsonError('Action not found', 404);
}

// ─── Register Face ───
function handleRegister() {
    $user = requireAuth();
    $body = getBody();
    $pdo = getDB();

    $features = $body['features'] ?? [];
    $photoUrl = $body['photo_url'] ?? '';

    if (empty($features)) jsonError('بيانات الوجه مطلوبة');

    $pdo->prepare("INSERT INTO face_data (uid, user_name, registered, features, photo_url, feature_count) VALUES (?, ?, 1, ?, ?, ?) ON DUPLICATE KEY UPDATE registered=1, features=?, photo_url=?, feature_count=?, registered_at=NOW()")
        ->execute([
            $user['uid'], $user['name'],
            json_encode($features), $photoUrl, count($features),
            json_encode($features), $photoUrl, count($features)
        ]);

    // Update user record
    $pdo->prepare("UPDATE users SET face_registered = 1, face_photo_url = ? WHERE uid = ?")
        ->execute([$photoUrl, $user['uid']]);

    jsonResponse(['success' => true, 'photoUrl' => $photoUrl]);
}

// ─── Verify Face ───
function handleVerify() {
    $user = requireAuth();
    $body = getBody();
    $pdo = getDB();

    $currentFeatures = $body['features'] ?? [];
    $photoUrl = $body['photo_url'] ?? '';

    if (empty($currentFeatures)) jsonError('بيانات الوجه مطلوبة');

    // Get registered features
    $stmt = $pdo->prepare("SELECT * FROM face_data WHERE uid = ? AND registered = 1");
    $stmt->execute([$user['uid']]);
    $faceData = $stmt->fetch();

    if (!$faceData) {
        jsonResponse(['success' => false, 'error' => 'لم يتم تسجيل بصمة الوجه بعد', 'needsRegistration' => true]);
    }

    $registeredFeatures = json_decode($faceData['features'], true) ?? [];
    if (empty($registeredFeatures)) {
        jsonResponse(['success' => false, 'error' => 'بيانات الوجه تالفة — أعد التسجيل', 'needsRegistration' => true]);
    }

    // Compare faces (same algorithm as Flutter)
    $similarity = compareFaces($registeredFeatures, $currentFeatures);
    $threshold = 0.65;
    $matched = $similarity >= $threshold;

    // Log verification
    $pdo->prepare("INSERT INTO face_verifications (uid, photo_url, similarity, matched, threshold) VALUES (?, ?, ?, ?, ?)")
        ->execute([$user['uid'], $photoUrl, $similarity, $matched ? 1 : 0, $threshold]);

    if ($matched) {
        jsonResponse(['success' => true, 'similarity' => $similarity, 'photoUrl' => $photoUrl]);
    } else {
        jsonResponse(['success' => false, 'error' => 'الوجه غير مطابق — تأكد من الإضاءة وأعد المحاولة', 'similarity' => $similarity, 'photoUrl' => $photoUrl]);
    }
}

// ─── Get Face Registration Status ───
function handleStatus() {
    $user = requireAuth();
    $uid = $_GET['uid'] ?? $user['uid'];
    $pdo = getDB();

    $stmt = $pdo->prepare("SELECT uid, user_name, registered, photo_url, feature_count, registered_at FROM face_data WHERE uid = ?");
    $stmt->execute([$uid]);
    $data = $stmt->fetch();

    jsonResponse(['success' => true, 'registered' => $data ? (bool)$data['registered'] : false, 'data' => $data]);
}

// ─── Get Verification History ───
function handleHistory() {
    $user = requireAuth();
    $uid = $_GET['uid'] ?? $user['uid'];
    $limit = min(intval($_GET['limit'] ?? 20), 100);
    $pdo = getDB();

    $stmt = $pdo->prepare("SELECT * FROM face_verifications WHERE uid = ? ORDER BY timestamp DESC LIMIT ?");
    $stmt->execute([$uid, $limit]);

    jsonResponse(['success' => true, 'verifications' => $stmt->fetchAll()]);
}

// ─── Reset Face Registration (Admin) ───
function handleReset() {
    $admin = requireAuth();
    if ($admin['role'] !== 'admin') jsonError('غير مصرح', 403);

    $body = getBody();
    $uid = $body['uid'] ?? '';
    if (empty($uid)) jsonError('uid مطلوب');

    $pdo = getDB();
    $pdo->prepare("DELETE FROM face_data WHERE uid = ?")->execute([$uid]);
    $pdo->prepare("UPDATE users SET face_photo_url = NULL, face_registered = 0 WHERE uid = ?")->execute([$uid]);

    jsonResponse(['success' => true]);
}

// ─── Compare face features (same logic as Flutter) ───
function compareFaces($registered, $current) {
    if (empty($registered) || empty($current)) return 0;
    $len = min(count($registered), count($current));
    $sumSq = 0;
    for ($i = 0; $i < $len; $i++) {
        $diff = $registered[$i] - $current[$i];
        $sumSq += $diff * $diff;
    }
    $distance = sqrt($sumSq / $len);
    return 1.0 / (1.0 + $distance * 5);
}
