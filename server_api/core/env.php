<?php
function loadEnv($path) {
    if (!file_exists($path)) return false;
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if (empty($line) || $line[0] === '#') continue;
        $pos = strpos($line, '=');
        if ($pos === false) continue;
        $key = trim(substr($line, 0, $pos));
        $value = trim(substr($line, $pos + 1));
        if (strlen($value) >= 2) {
            $f = $value[0]; $l = $value[strlen($value)-1];
            if (($f === '"' && $l === '"') || ($f === "'" && $l === "'")) $value = substr($value, 1, -1);
        }
        $_ENV[$key] = $value;
        putenv("$key=$value");
    }
    return true;
}

function env($key, $default = null) {
    $value = $_ENV[$key] ?? getenv($key);
    if ($value === false || $value === null) return $default;
    $lower = strtolower($value);
    if ($lower === 'true') return true;
    if ($lower === 'false') return false;
    if ($lower === 'null') return null;
    return $value;
}
