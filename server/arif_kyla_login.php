<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

$input = arif_kyla_json_input();
$phone = arif_kyla_normalize_phone((string) ($input['phone'] ?? ''));
$password = (string) ($input['password'] ?? '');

if (strlen($phone) !== 11) {
    arif_kyla_send_json(['error' => 'Enter a valid 11-digit phone number'], 400);
}

$db = arif_kyla_db();
$stmt = $db->prepare('SELECT * FROM users WHERE phone = ?');
$stmt->execute([$phone]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    arif_kyla_send_json(['error' => 'No account found for this phone number'], 404);
}
if (!password_verify($password, $user['password_hash'])) {
    arif_kyla_send_json(['error' => 'Incorrect password'], 401);
}

$token = bin2hex(random_bytes(32));
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);
$update = $db->prepare('UPDATE users SET session_token = ?, session_created_at = ? WHERE phone = ?');
$update->execute([$token, $now, $phone]);

$user['session_token'] = $token;
arif_kyla_send_json(arif_kyla_user_payload($user) + ['token' => $token]);
