<?php
/**
 * Dawemly API - Super Admin Endpoints
 * POST /api/superadmin.php?action=login
 * GET  /api/superadmin.php?action=organizations
 * POST /api/superadmin.php?action=save_organization
 * POST /api/superadmin.php?action=toggle_org
 * GET  /api/superadmin.php?action=plans
 * POST /api/superadmin.php?action=save_plan
 * GET  /api/superadmin.php?action=stats
 * GET  /api/superadmin.php?action=org_details&id=X
 */

require_once __DIR__ . '/../core/bootstrap.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'login': handleSuperLogin(); break;
    case 'me': handleSuperMe(); break;
    case 'organizations': handleGetOrgs(); break;
    case 'save_organization': handleSaveOrg(); break;
    case 'toggle_org': handleToggleOrg(); break;
    case 'plans': handleGetPlans(); break;
    case 'save_plan': handleSavePlan(); break;
    case 'stats': handleStats(); break;
    case 'org_details': handleOrgDetails(); break;
    case 'org_usage': handleOrgUsage(); break;
    default: jsonError('Action not found', 404);
}

// ─── Super Admin Auth ───
function requireSuperAuth() {
    $headers = getallheaders();
    $auth = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    if (empty($auth) || !str_starts_with($auth, 'Bearer ')) {
        jsonError('غير مصرح', 401);
    }
    $token = substr($auth, 7);
    $pdo = getDB();
    $stmt = $pdo->prepare("SELECT t.uid, s.name, s.email FROM api_tokens t JOIN super_admins s ON t.uid = CONCAT('super_', s.id) WHERE t.token = ? AND (t.expires_at IS NULL OR t.expires_at > NOW())");
    $stmt->execute([$token]);
    $user = $stmt->fetch();
    if (!$user) jsonError('جلسة منتهية', 401);
    return $user;
}

// ─── Login ───
function handleSuperLogin() {
    $body = getBody();
    $email = $body['email'] ?? '';
    $password = $body['password'] ?? '';
    if (empty($email) || empty($password)) jsonError('البريد وكلمة المرور مطلوبين');

    $pdo = getDB();
    $stmt = $pdo->prepare("SELECT * FROM super_admins WHERE email = ? AND active = 1");
    $stmt->execute([$email]);
    $admin = $stmt->fetch();

    if (!$admin || !password_verify($password, $admin['password'])) {
        jsonError('بيانات الدخول غير صحيحة');
    }

    $token = generateToken();
    $uid = 'super_' . $admin['id'];
    $pdo->prepare("INSERT INTO api_tokens (uid, token, device_info, expires_at) VALUES (?, ?, 'super_admin', DATE_ADD(NOW(), INTERVAL 30 DAY))")
        ->execute([$uid, $token]);

    jsonResponse(['success' => true, 'token' => $token, 'user' => ['uid' => $uid, 'name' => $admin['name'], 'email' => $admin['email'], 'role' => 'superadmin']]);
}

// ─── Me ───
function handleSuperMe() {
    $user = requireSuperAuth();
    jsonResponse(['success' => true, 'user' => $user]);
}

// ─── Get Organizations ───
function handleGetOrgs() {
    requireSuperAuth();
    $pdo = getDB();
    $stmt = $pdo->query("
        SELECT o.*, p.name as plan_name, p.max_employees, p.max_branches,
        (SELECT COUNT(*) FROM users u WHERE u.org_id = o.id AND u.active = 1) as current_employees,
        (SELECT COUNT(*) FROM branches b WHERE b.org_id = o.id) as current_branches
        FROM organizations o
        LEFT JOIN plans p ON o.plan_id = p.id
        ORDER BY o.created_at DESC
    ");
    jsonResponse(['success' => true, 'organizations' => $stmt->fetchAll()]);
}

// ─── Save Organization ───
function handleSaveOrg() {
    requireSuperAuth();
    $body = getBody();
    $pdo = getDB();

    if (!empty($body['id'])) {
        // Update
        $stmt = $pdo->prepare("UPDATE organizations SET name=?, name_en=?, email=?, phone=?, address=?, plan_id=?, subscription_start=?, subscription_end=? WHERE id=?");
        $stmt->execute([
            $body['name'] ?? '', $body['name_en'] ?? '', $body['email'] ?? '',
            $body['phone'] ?? '', $body['address'] ?? '', $body['plan_id'] ?? null,
            $body['subscription_start'] ?? null, $body['subscription_end'] ?? null,
            $body['id']
        ]);
        jsonResponse(['success' => true, 'id' => $body['id']]);
    } else {
        // Create
        $stmt = $pdo->prepare("INSERT INTO organizations (name, name_en, email, phone, address, plan_id, subscription_start, subscription_end) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
        $stmt->execute([
            $body['name'] ?? '', $body['name_en'] ?? '', $body['email'] ?? '',
            $body['phone'] ?? '', $body['address'] ?? '', $body['plan_id'] ?? null,
            $body['subscription_start'] ?? date('Y-m-d'), $body['subscription_end'] ?? date('Y-m-d', strtotime('+1 year'))
        ]);
        $orgId = $pdo->lastInsertId();

        // Create default branch
        $pdo->prepare("INSERT INTO branches (org_id, name) VALUES (?, ?)")
            ->execute([$orgId, 'الفرع الرئيسي']);

        // Create admin user for this org
        if (!empty($body['admin_email']) && !empty($body['admin_password'])) {
            $uid = generateUID();
            $pdo->prepare("INSERT INTO users (uid, org_id, email, password, name, role, emp_id, active) VALUES (?, ?, ?, ?, ?, 'admin', ?, 1)")
                ->execute([$uid, $orgId, $body['admin_email'], password_hash($body['admin_password'], PASSWORD_DEFAULT), $body['admin_name'] ?? 'مدير النظام', 'ADM-' . substr(time(), -6)]);
        }

        jsonResponse(['success' => true, 'id' => $orgId]);
    }
}

// ─── Toggle Organization ───
function handleToggleOrg() {
    requireSuperAuth();
    $body = getBody();
    $pdo = getDB();
    $pdo->prepare("UPDATE organizations SET active = NOT active WHERE id = ?")
        ->execute([$body['id']]);
    jsonResponse(['success' => true]);
}

// ─── Get Plans ───
function handleGetPlans() {
    requireSuperAuth();
    $pdo = getDB();
    $stmt = $pdo->query("SELECT * FROM plans ORDER BY price_monthly ASC");
    jsonResponse(['success' => true, 'plans' => $stmt->fetchAll()]);
}

// ─── Save Plan ───
function handleSavePlan() {
    requireSuperAuth();
    $body = getBody();
    $pdo = getDB();

    $fields = ['name', 'name_en', 'max_employees', 'max_branches', 'max_locations', 'max_radius', 'max_supervisors',
        'allow_face_auth', 'allow_reports_pdf', 'allow_reports_excel', 'allow_leave_balance',
        'allow_salary_calc', 'allow_overtime', 'allow_verification', 'allow_schedules', 'price_monthly', 'price_yearly'];

    if (!empty($body['id'])) {
        $sets = implode(', ', array_map(fn($f) => "$f = ?", $fields));
        $stmt = $pdo->prepare("UPDATE plans SET $sets WHERE id = ?");
        $params = array_map(fn($f) => $body[$f] ?? null, $fields);
        $params[] = $body['id'];
        $stmt->execute($params);
    } else {
        $cols = implode(', ', $fields);
        $placeholders = implode(', ', array_fill(0, count($fields), '?'));
        $stmt = $pdo->prepare("INSERT INTO plans ($cols) VALUES ($placeholders)");
        $stmt->execute(array_map(fn($f) => $body[$f] ?? null, $fields));
    }
    jsonResponse(['success' => true]);
}

// ─── Dashboard Stats ───
function handleStats() {
    requireSuperAuth();
    $pdo = getDB();

    $totalOrgs = $pdo->query("SELECT COUNT(*) FROM organizations")->fetchColumn();
    $activeOrgs = $pdo->query("SELECT COUNT(*) FROM organizations WHERE active = 1")->fetchColumn();
    $totalUsers = $pdo->query("SELECT COUNT(*) FROM users WHERE active = 1")->fetchColumn();
    $todayAttendance = $pdo->query("SELECT COUNT(*) FROM attendance_daily WHERE dateKey = '" . date('Y-m-d') . "'")->fetchColumn();

    jsonResponse(['success' => true, 'stats' => [
        'total_organizations' => (int)$totalOrgs,
        'active_organizations' => (int)$activeOrgs,
        'total_users' => (int)$totalUsers,
        'today_attendance' => (int)$todayAttendance,
    ]]);
}

// ─── Organization Details ───
function handleOrgDetails() {
    requireSuperAuth();
    $id = $_GET['id'] ?? 0;
    $pdo = getDB();

    $org = $pdo->prepare("SELECT o.*, p.name as plan_name FROM organizations o LEFT JOIN plans p ON o.plan_id = p.id WHERE o.id = ?");
    $org->execute([$id]);
    $orgData = $org->fetch();
    if (!$orgData) jsonError('المؤسسة غير موجودة', 404);

    $users = $pdo->prepare("SELECT uid, name, email, role, dept, active, emp_id FROM users WHERE org_id = ? ORDER BY name");
    $users->execute([$id]);

    $branches = $pdo->prepare("SELECT * FROM branches WHERE org_id = ?");
    $branches->execute([$id]);

    jsonResponse(['success' => true, 'organization' => $orgData, 'users' => $users->fetchAll(), 'branches' => $branches->fetchAll()]);
}

// ─── Organization Usage ───
function handleOrgUsage() {
    requireSuperAuth();
    $id = $_GET['id'] ?? 0;
    $pdo = getDB();

    $plan = $pdo->prepare("SELECT p.* FROM plans p JOIN organizations o ON o.plan_id = p.id WHERE o.id = ?");
    $plan->execute([$id]);
    $planData = $plan->fetch();

    $empCount = $pdo->prepare("SELECT COUNT(*) FROM users WHERE org_id = ? AND active = 1");
    $empCount->execute([$id]);

    $branchCount = $pdo->prepare("SELECT COUNT(*) FROM branches WHERE org_id = ?");
    $branchCount->execute([$id]);

    $locCount = $pdo->prepare("SELECT COUNT(*) FROM locations WHERE org_id = ?");
    $locCount->execute([$id]);

    jsonResponse(['success' => true, 'usage' => [
        'employees' => ['used' => (int)$empCount->fetchColumn(), 'limit' => (int)($planData['max_employees'] ?? 0)],
        'branches' => ['used' => (int)$branchCount->fetchColumn(), 'limit' => (int)($planData['max_branches'] ?? 0)],
        'locations' => ['used' => (int)$locCount->fetchColumn(), 'limit' => (int)($planData['max_locations'] ?? 0)],
    ]]);
}
