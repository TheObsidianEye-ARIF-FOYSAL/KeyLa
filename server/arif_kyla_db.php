<?php

date_default_timezone_set('UTC');

// ARIF(KyLa) — account + encrypted vault backup backend for the Keyla
// password manager. Structured identically to med_remind_v2/server's
// medremind_db.php: a shared SQLite storage + helper file, phone+password
// identity, PHP password_hash/password_verify, opaque session tokens.
//
// Security note (Keyla-specific, no equivalent needed in MedRemind): the
// "password" this server ever sees is NOT the user's Keyla master
// password. The app derives a separate server-auth secret from the master
// password via a domain-separated Argon2id call
// (KdfService.deriveServerAuthSecret) before it's ever sent here, and the
// vault blob this server stores is already client-side encrypted
// ciphertext. This server can never read a plaintext credential.

function arif_kyla_db(): PDO {
    $dbPath = __DIR__ . '/arif_kyla_users.db';
    $pdo = new PDO('sqlite:' . $dbPath);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->exec("CREATE TABLE IF NOT EXISTS users (
        phone TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        session_token TEXT,
        session_created_at TEXT
    )");
    $pdo->exec("CREATE TABLE IF NOT EXISTS vault_blobs (
        phone TEXT PRIMARY KEY,
        blob TEXT NOT NULL,
        kdf_salt TEXT NOT NULL,
        kdf_params TEXT NOT NULL,
        version INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(phone) REFERENCES users(phone)
    )");
    return $pdo;
}

// Mirrors AuthService._normalize in the MedRemind app's
// lib/features/auth/services/auth_service.dart so phone formatting stays
// consistent between apps built on this same server pattern.
function arif_kyla_normalize_phone(string $phone): string {
    $digits = preg_replace('/\D/', '', $phone) ?? '';
    if (strpos($digits, '880') === 0 && strlen($digits) > 10) {
        return substr($digits, 3);
    }
    if (strpos($digits, '88') === 0 && strlen($digits) > 11) {
        return substr($digits, 2);
    }
    return $digits;
}

function arif_kyla_json_input(): array {
    $body = file_get_contents('php://input');
    $data = json_decode($body, true);
    if (is_array($data)) return $data;
    return $_POST;
}

function arif_kyla_send_json($data, int $status = 200): void {
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}

function arif_kyla_cors(): void {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function arif_kyla_require_session(PDO $db, string $phone, string $token): array {
    if ($phone === '' || $token === '') {
        arif_kyla_send_json(['error' => 'Invalid session'], 401);
    }
    $stmt = $db->prepare('SELECT * FROM users WHERE phone = ?');
    $stmt->execute([$phone]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$user || !is_string($user['session_token']) || !hash_equals($user['session_token'], $token)) {
        arif_kyla_send_json(['error' => 'Invalid session'], 401);
    }
    return $user;
}

function arif_kyla_user_payload(array $user): array {
    return [
        'phone' => $user['phone'],
        'name' => $user['name'],
    ];
}
