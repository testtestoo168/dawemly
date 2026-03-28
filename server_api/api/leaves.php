<?php
/**
 * Dawemly API - Leave Balance Endpoints (أرصدة الإجازات)
 * GET  /api/leaves.php?action=balance
 * GET  /api/leaves.php?action=balance&uid=xxx (admin)
 * POST /api/leaves.php?action=set_balance (admin)
 * GET  /api/leaves.php?action=all_balances (admin)
 */

require_once __DIR__ . '/../core/bootstrap.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'balance': handleGetBalance(); break;
    case 'set_balance': handleSetBalance(); break;
    case 'all_balances': handleAllBalances(); break;
    default: jsonError('Action not found', 404);
}

// ─── Get Leave Balance ───
function handleGetBalance() {
    $user = requireAuth();
    $uid = $_GET['uid'] ?? $user['uid'];

    // Only admin can view other users' balance
    if ($uid !== $user['uid'] && $user['role'] !== 'admin') {
        jsonError('غير مصرح', 403);
    }

    $pdo = getDB();
    $year = (int)($_GET['year'] ?? date('Y'));

    $stmt = $pdo->prepare("SELECT * FROM leave_balances WHERE uid = ? AND year = ?");
    $stmt->execute([$uid, $year]);
    $balance = $stmt->fetch();

    if (!$balance) {
        // Create default balance
        $pdo->prepare("INSERT INTO leave_balances (uid, org_id, year, annual_total, sick_total, emergency_total) VALUES (?, ?, ?, 21, 10, 5)")
            ->execute([$uid, $user['org_id'] ?? null, $year]);
        $stmt->execute([$uid, $year]);
        $balance = $stmt->fetch();
    }

    $balance['annual_remaining'] = $balance['annual_total'] - $balance['annual_used'];
    $balance['sick_remaining'] = $balance['sick_total'] - $balance['sick_used'];
    $balance['emergency_remaining'] = $balance['emergency_total'] - $balance['emergency_used'];

    jsonResponse(['success' => true, 'balance' => $balance]);
}

// ─── Set Leave Balance (Admin) ───
function handleSetBalance() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $body = getBody();
    $uid = $body['uid'] ?? '';
    $year = (int)($body['year'] ?? date('Y'));

    if (empty($uid)) jsonError('uid مطلوب');

    $pdo = getDB();
    $stmt = $pdo->prepare("INSERT INTO leave_balances (uid, org_id, year, annual_total, sick_total, emergency_total) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE annual_total=VALUES(annual_total), sick_total=VALUES(sick_total), emergency_total=VALUES(emergency_total)");
    $stmt->execute([
        $uid, $user['org_id'] ?? null, $year,
        $body['annual_total'] ?? 21,
        $body['sick_total'] ?? 10,
        $body['emergency_total'] ?? 5
    ]);

    jsonResponse(['success' => true]);
}

// ─── Get All Balances (Admin) ───
function handleAllBalances() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $pdo = getDB();
    $year = (int)($_GET['year'] ?? date('Y'));

    $stmt = $pdo->prepare("
        SELECT lb.*, u.name, u.emp_id, u.dept
        FROM leave_balances lb
        JOIN users u ON lb.uid = u.uid
        WHERE lb.year = ? AND u.active = 1
        ORDER BY u.name
    ");
    $stmt->execute([$year]);

    jsonResponse(['success' => true, 'balances' => $stmt->fetchAll()]);
}
