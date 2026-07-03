<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

// "password" here is the app's server-auth secret (derived from the Keyla
// master password via KdfService.deriveServerAuthSecret), never the master
// password itself. See arif_kyla_db.php's header comment.
$input = arif_kyla_json_input();
$phone = arif_kyla_normalize_phone((string) ($input['phone'] ?? ''));
$name = trim((string) ($input['name'] ?? ''));
$password = (string) ($input['password'] ?? '');

if (strlen($phone) !== 11) {
    arif_kyla_send_json(['error' => 'Enter a valid 11-digit phone number'], 400);
}
if ($name === '') {
    arif_kyla_send_json(['error' => 'Name is required'], 400);
}
if (strlen($password) < 6) {
    arif_kyla_send_json(['error' => 'Password must be at least 6 characters'], 400);
}

$db = arif_kyla_db();

$stmt = $db->prepare('SELECT 1 FROM users WHERE phone = ?');
$stmt->execute([$phone]);
if ($stmt->fetchColumn()) {
    arif_kyla_send_json(['error' => 'This phone number is already registered'], 409);
}

$passwordHash = password_hash($password, PASSWORD_BCRYPT);
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);
$token = bin2hex(random_bytes(32));

$insert = $db->prepare(
    'INSERT INTO users (phone, name, password_hash, created_at, session_token, session_created_at)
     VALUES (?, ?, ?, ?, ?, ?)'
);
$insert->execute([$phone, $name, $passwordHash, $now, $token, $now]);

arif_kyla_send_json(['phone' => $phone, 'name' => $name, 'token' => $token]);
