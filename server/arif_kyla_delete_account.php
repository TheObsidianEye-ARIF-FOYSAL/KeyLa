<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

// Unlike MedRemind's medremind_unsubscribe.php, Keyla has no carrier-billing
// subscription to opt out of first — this just deletes the account and its
// backup row once the session is verified.
$input = arif_kyla_json_input();
$phone = arif_kyla_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');

$db = arif_kyla_db();
arif_kyla_require_session($db, $phone, $token);

$db->prepare('DELETE FROM vault_blobs WHERE phone = ?')->execute([$phone]);
$db->prepare('DELETE FROM users WHERE phone = ?')->execute([$phone]);

arif_kyla_send_json(['success' => true]);
