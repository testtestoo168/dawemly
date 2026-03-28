<?php
/**
 * Dawemly API - Core Bootstrap
 */

// CORS Headers
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Load environment
require_once __DIR__ . '/env.php';
loadEnv(__DIR__ . '/../.env');

// Database connection
function getDB() {
    static $pdo = null;
    if ($pdo === null) {
        $host = env('DB_HOST', 'localhost');
        $name = env('DB_NAME', 'dawemly');
        $user = env('DB_USER', 'root');
        $pass = env('DB_PASS', '');
        $charset = env('DB_CHARSET', 'utf8mb4');

        $pdo = new PDO(
            "mysql:host={$host};dbname={$name};charset={$charset}",
            $user, $pass,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
    }
    return $pdo;
}

// JSON Response helper
function jsonResponse($data, $code = 200) {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function jsonError($message, $code = 400) {
    jsonResponse(['success' => false, 'error' => $message], $code);
}

// Get JSON body
function getBody() {
    return json_decode(file_get_contents('php://input'), true) ?? [];
}

// Auth middleware - verify token
function requireAuth() {
    $headers = getallheaders();
    $auth = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    
    if (empty($auth) || !str_starts_with($auth, 'Bearer ')) {
        jsonError('غير مصرح — سجل الدخول أولاً', 401);
    }
    
    $token = substr($auth, 7);
    $pdo = getDB();
    
    $stmt = $pdo->prepare("
        SELECT t.uid, u.name, u.email, u.role, u.emp_id, u.active, u.dept,
               u.face_registered, u.face_photo_url, u.auth_override, 
               u.auth_face, u.auth_biometric, u.auth_loc, u.fcm_token
        FROM api_tokens t 
        JOIN users u ON t.uid = u.uid 
        WHERE t.token = ? AND (t.expires_at IS NULL OR t.expires_at > NOW())
    ");
    $stmt->execute([$token]);
    $user = $stmt->fetch();
    
    if (!$user) {
        jsonError('جلسة منتهية — سجل الدخول مرة أخرى', 401);
    }
    
    if (!$user['active']) {
        jsonError('حسابك معطل — تواصل مع المدير', 403);
    }
    
    return $user;
}

// Generate unique ID
function generateUID() {
    return bin2hex(random_bytes(16));
}

// Generate API token
function generateToken() {
    return bin2hex(random_bytes(32));
}
