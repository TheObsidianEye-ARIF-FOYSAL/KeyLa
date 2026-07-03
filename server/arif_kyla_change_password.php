<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

// Change the server-auth secret for an already-logged-in account. The app
// calls this after the user changes their Keyla master password, passing
// the old and new secrets re-derived locally via KdfService — never the
// master passwords themselves.
$input = arif_kyla_json_input();
$phone = arif_kyla_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');
$currentPassword = (string) ($input['currentPassword'] ?? '');
$newPassword = (string) ($input['newPassword'] ?? '');

$db = arif_kyla_db();
$user = arif_kyla_require_session($db, $phone, $token);

if (!password_verify($currentPassword, $user['password_hash'])) {
    arif_kyla_send_json(['error' => 'Current password is incorrect'], 401);
}
if (strlen($newPassword) < 6) {
    arif_kyla_send_json(['error' => 'New password must be at least 6 characters'], 400);
}

$passwordHash = password_hash($newPassword, PASSWORD_BCRYPT);
// Rotate the session token so the change also invalidates any other
// signed-in device/session, and return the new token to keep this one alive.
$newToken = bin2hex(random_bytes(32));
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);

$update = $db->prepare(
    'UPDATE users SET password_hash = ?, session_token = ?, session_created_at = ? WHERE phone = ?'
);
$update->execute([$passwordHash, $newToken, $now, $phone]);

arif_kyla_send_json(['success' => true, 'token' => $newToken]);
