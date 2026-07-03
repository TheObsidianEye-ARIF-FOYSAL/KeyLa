<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

$input = arif_kyla_json_input();
$email = arif_kyla_normalize_email((string) ($input['email'] ?? ''));
$token = (string) ($input['token'] ?? '');

$db = arif_kyla_db();
$user = arif_kyla_require_session($db, $email, $token);

$db->prepare('DELETE FROM vault_blobs WHERE user_id = ?')->execute([$user['id']]);
$db->prepare('DELETE FROM users WHERE id = ?')->execute([$user['id']]);

arif_kyla_send_json(['ok' => true]);
