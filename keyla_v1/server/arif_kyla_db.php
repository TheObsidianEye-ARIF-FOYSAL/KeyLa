<?php

date_default_timezone_set('UTC');

// ARIF(KyLa) — backup/sync backend for the Keyla password manager.
//
// This server NEVER receives plaintext passwords or the user's master
// password. It only ever sees:
//   1. A "server auth secret" derived from the master password via a
//      domain-separated Argon2id call (KdfService.deriveServerAuthSecret in
//      the Flutter app) — this cannot be used to reconstruct the vault key.
//   2. The already envelope-encrypted vault blob the app exports locally
//      (wrapped vault key + per-field ciphertext), which this server stores
//      and returns opaquely without ever decrypting it.
//
// Structurally mirrors med_remind_v2/server/medremind_db.php: flat PHP
// scripts, PDO/SQLite, phone-style session tokens (here keyed by email).

function arif_kyla_db(): PDO {
    $dbPath = __DIR__ . '/arif_kyla_users.db';
    $pdo = new PDO('sqlite:' . $dbPath);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->exec("CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        auth_secret_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        session_token TEXT,
        session_created_at TEXT
    )");
    $pdo->exec("CREATE TABLE IF NOT EXISTS vault_blobs (
        user_id INTEGER PRIMARY KEY,
        blob TEXT NOT NULL,
        kdf_salt TEXT NOT NULL,
        kdf_params TEXT NOT NULL,
        version INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id)
    )");
    return $pdo;
}

function arif_kyla_normalize_email(string $email): string {
    return strtolower(trim($email));
}

function arif_kyla_json_input(): array {
    $body = file_get_contents('php://input');
    $data = json_decode($body, true);
    return is_array($data) ? $data : [];
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

function arif_kyla_require_session(PDO $db, string $email, string $token): array {
    if ($email === '' || $token === '') {
        arif_kyla_send_json(['error' => 'Invalid session'], 401);
    }
    $stmt = $db->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$user || !is_string($user['session_token']) || !hash_equals($user['session_token'], $token)) {
        arif_kyla_send_json(['error' => 'Invalid session'], 401);
    }
    return $user;
}
