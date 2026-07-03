<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

$input = arif_kyla_json_input();
$email = arif_kyla_normalize_email((string) ($input['email'] ?? ''));
$authSecret = (string) ($input['authSecret'] ?? ''); // base64 Argon2id output, NOT the master password

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    arif_kyla_send_json(['error' => 'Enter a valid email address'], 400);
}
if (strlen($authSecret) < 20) {
    arif_kyla_send_json(['error' => 'Invalid auth secret'], 400);
}

$db = arif_kyla_db();

$stmt = $db->prepare('SELECT 1 FROM users WHERE email = ?');
$stmt->execute([$email]);
if ($stmt->fetchColumn()) {
    arif_kyla_send_json(['error' => 'This email is already registered'], 409);
}

$authSecretHash = password_hash($authSecret, PASSWORD_BCRYPT);
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);
$token = bin2hex(random_bytes(32));

$insert = $db->prepare(
    'INSERT INTO users (email, auth_secret_hash, created_at, session_token, session_created_at)
     VALUES (?, ?, ?, ?, ?)'
);
$insert->execute([$email, $authSecretHash, $now, $token, $now]);

arif_kyla_send_json(['email' => $email, 'token' => $token]);
