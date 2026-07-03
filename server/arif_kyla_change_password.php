<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

// Called after the app has already derived a new server-auth secret from
// the user's new master password (KdfService.deriveServerAuthSecret). This
// endpoint never sees a master password, old or new — only the derived
// secrets.
$input = arif_kyla_json_input();
$email = arif_kyla_normalize_email((string) ($input['email'] ?? ''));
$token = (string) ($input['token'] ?? '');
$newAuthSecret = (string) ($input['newAuthSecret'] ?? '');

if (strlen($newAuthSecret) < 20) {
    arif_kyla_send_json(['error' => 'Invalid auth secret'], 400);
}

$db = arif_kyla_db();
$user = arif_kyla_require_session($db, $email, $token);

$newHash = password_hash($newAuthSecret, PASSWORD_BCRYPT);
$stmt = $db->prepare('UPDATE users SET auth_secret_hash = ? WHERE id = ?');
$stmt->execute([$newHash, $user['id']]);

arif_kyla_send_json(['ok' => true]);
