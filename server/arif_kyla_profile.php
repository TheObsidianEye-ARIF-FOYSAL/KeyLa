<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

// Used to restore a session on app start (see UserAuthService.restoreSession
// in the Flutter app) and to re-fetch the account name on demand.
$input = arif_kyla_json_input();
$phone = arif_kyla_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');

$db = arif_kyla_db();
$user = arif_kyla_require_session($db, $phone, $token);

arif_kyla_send_json(arif_kyla_user_payload($user));
