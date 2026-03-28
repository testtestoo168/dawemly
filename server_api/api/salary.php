<?php
/**
 * Dawemly API - Salary & Deductions Endpoints (حساب الرواتب والخصومات)
 * GET  /api/salary.php?action=calculate&month=3&year=2026
 * GET  /api/salary.php?action=employee&uid=xxx&month=3&year=2026
 * GET  /api/salary.php?action=all&month=3&year=2026 (admin)
 * POST /api/salary.php?action=save_settings (admin)
 * GET  /api/salary.php?action=get_settings
 */

require_once __DIR__ . '/../core/bootstrap.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'calculate': handleCalculate(); break;
    case 'employee': handleEmployee(); break;
    case 'all': handleAll(); break;
    case 'save_settings': handleSaveSettings(); break;
    case 'get_settings': handleGetSettings(); break;
    default: jsonError('Action not found', 404);
}

// ─── Calculate salary deductions for current user ───
function handleCalculate() {
    $user = requireAuth();
    $month = (int)($_GET['month'] ?? date('n'));
    $year = (int)($_GET['year'] ?? date('Y'));

    $result = calculateForUser($user['uid'], $month, $year);
    jsonResponse(['success' => true, 'salary' => $result]);
}

// ─── Get specific employee salary (admin) ───
function handleEmployee() {
    $user = requireAuth();
    $uid = $_GET['uid'] ?? $user['uid'];
    if ($uid !== $user['uid'] && $user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $month = (int)($_GET['month'] ?? date('n'));
    $year = (int)($_GET['year'] ?? date('Y'));

    $result = calculateForUser($uid, $month, $year);
    jsonResponse(['success' => true, 'salary' => $result]);
}

// ─── Get all employees salary (admin) ───
function handleAll() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $month = (int)($_GET['month'] ?? date('n'));
    $year = (int)($_GET['year'] ?? date('Y'));

    $pdo = getDB();
    $stmt = $pdo->query("SELECT uid, name, emp_id, dept FROM users WHERE active = 1 AND role != 'admin' ORDER BY name");
    $employees = $stmt->fetchAll();

    $results = [];
    foreach ($employees as $emp) {
        $calc = calculateForUser($emp['uid'], $month, $year);
        $calc['name'] = $emp['name'];
        $calc['emp_id'] = $emp['emp_id'];
        $calc['dept'] = $emp['dept'];
        $results[] = $calc;
    }

    jsonResponse(['success' => true, 'records' => $results]);
}

// ─── Save deduction settings ───
function handleSaveSettings() {
    $user = requireAuth();
    if ($user['role'] !== 'admin') jsonError('غير مصرح', 403);

    $body = getBody();
    $pdo = getDB();

    $settings = json_encode([
        'late_deduction_per_minute' => $body['late_deduction_per_minute'] ?? 1,
        'absent_deduction_per_day' => $body['absent_deduction_per_day'] ?? 100,
        'overtime_rate' => $body['overtime_rate'] ?? 1.5,
        'late_grace_minutes' => $body['late_grace_minutes'] ?? 15,
        'standard_hours' => $body['standard_hours'] ?? 8,
    ]);

    $pdo->prepare("INSERT INTO settings (setting_key, setting_value) VALUES ('salary', ?) ON DUPLICATE KEY UPDATE setting_value = ?")
        ->execute([$settings, $settings]);

    jsonResponse(['success' => true]);
}

// ─── Get deduction settings ───
function handleGetSettings() {
    requireAuth();
    $pdo = getDB();
    $stmt = $pdo->prepare("SELECT setting_value FROM settings WHERE setting_key = 'salary'");
    $stmt->execute();
    $row = $stmt->fetch();
    $settings = $row ? json_decode($row['setting_value'], true) : [
        'late_deduction_per_minute' => 1,
        'absent_deduction_per_day' => 100,
        'overtime_rate' => 1.5,
        'late_grace_minutes' => 15,
        'standard_hours' => 8,
    ];
    jsonResponse(['success' => true, 'settings' => $settings]);
}

// ─── Calculate for a specific user ───
function calculateForUser($uid, $month, $year) {
    $pdo = getDB();

    // Get salary settings
    $stmt = $pdo->prepare("SELECT setting_value FROM settings WHERE setting_key = 'salary'");
    $stmt->execute();
    $row = $stmt->fetch();
    $config = $row ? json_decode($row['setting_value'], true) : [];
    $lateDeductionPerMin = $config['late_deduction_per_minute'] ?? 1;
    $absentDeductionPerDay = $config['absent_deduction_per_day'] ?? 100;
    $overtimeRate = $config['overtime_rate'] ?? 1.5;
    $lateGrace = $config['late_grace_minutes'] ?? 15;
    $standardHours = $config['standard_hours'] ?? 8;

    // Get schedule info
    $monthStart = "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-01";
    $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
    $monthEnd = "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-$daysInMonth";

    // Count working days (exclude Friday/Saturday by default)
    $workingDays = 0;
    for ($d = 1; $d <= $daysInMonth; $d++) {
        $dayOfWeek = date('w', mktime(0, 0, 0, $month, $d, $year));
        if ($dayOfWeek != 5 && $dayOfWeek != 6) $workingDays++; // 5=Friday, 6=Saturday
    }

    // Get attendance records for this month
    $stmt = $pdo->prepare("SELECT * FROM attendance_daily WHERE uid = ? AND dateKey >= ? AND dateKey <= ? ORDER BY dateKey");
    $stmt->execute([$uid, $monthStart, $monthEnd]);
    $records = $stmt->fetchAll();

    $daysPresent = count($records);
    $daysAbsent = $workingDays - $daysPresent;
    if ($daysAbsent < 0) $daysAbsent = 0;

    $totalLateMinutes = 0;
    $lateCount = 0;
    $earlyLeaveCount = 0;
    $totalOvertimeMinutes = 0;

    foreach ($records as $rec) {
        $lateMin = (int)($rec['late_minutes'] ?? 0);
        if ($lateMin > $lateGrace) {
            $totalLateMinutes += ($lateMin - $lateGrace);
            $lateCount++;
        }

        $totalWorked = (int)($rec['totalWorkedMinutes'] ?? $rec['total_worked_minutes'] ?? 0);
        $standardMin = $standardHours * 60;
        if ($totalWorked > $standardMin) {
            $totalOvertimeMinutes += ($totalWorked - $standardMin);
        }

        if (($rec['is_early_leave'] ?? 0) == 1) $earlyLeaveCount++;
    }

    $deductionAbsent = $daysAbsent * $absentDeductionPerDay;
    $deductionLate = $totalLateMinutes * $lateDeductionPerMin;
    $overtimeAmount = ($totalOvertimeMinutes / 60.0) * $overtimeRate * ($absentDeductionPerDay / $standardHours);
    $totalDeductions = $deductionAbsent + $deductionLate;

    return [
        'uid' => $uid,
        'month' => $month,
        'year' => $year,
        'working_days' => $workingDays,
        'days_present' => $daysPresent,
        'days_absent' => $daysAbsent,
        'total_late_minutes' => $totalLateMinutes,
        'late_count' => $lateCount,
        'early_leave_count' => $earlyLeaveCount,
        'overtime_minutes' => $totalOvertimeMinutes,
        'overtime_amount' => round($overtimeAmount, 2),
        'deduction_absent' => round($deductionAbsent, 2),
        'deduction_late' => round($deductionLate, 2),
        'total_deductions' => round($totalDeductions, 2),
    ];
}
