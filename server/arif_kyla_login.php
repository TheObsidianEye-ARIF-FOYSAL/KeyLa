<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

$input = arif_kyla_json_input();
$email = arif_kyla_normalize_email((string) ($input['email'] ?? ''));
$authSecret = (string) ($input['authSecret'] ?? '');

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    arif_kyla_send_json(['error' => 'Enter a valid email address'], 400);
}

$db = arif_kyla_db();
$stmt = $db->prepare('SELECT * FROM users WHERE email = ?');
$stmt->execute([$email]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    arif_kyla_send_json(['error' => 'No account found for this email'], 404);
}
if (!password_verify($authSecret, $user['auth_secret_hash'])) {
    arif_kyla_send_json(['error' => 'Incorrect master password'], 401);
}

$token = bin2hex(random_bytes(32));
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);
$update = $db->prepare('UPDATE users SET session_token = ?, session_created_at = ? WHERE email = ?');
$update->execute([$token, $now, $email]);

arif_kyla_send_json(['email' => $email, 'token' => $token]);
