<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

$input = arif_kyla_json_input();
$phone = arif_kyla_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');
$blob = (string) ($input['blob'] ?? ''); // base64 of the app's already-encrypted vault export
$kdfSalt = (string) ($input['kdfSalt'] ?? '');
$kdfParams = $input['kdfParams'] ?? null;
$version = (int) ($input['version'] ?? 1);

$db = arif_kyla_db();
arif_kyla_require_session($db, $phone, $token);

if ($blob === '' || $kdfSalt === '' || !is_array($kdfParams)) {
    arif_kyla_send_json(['error' => 'Missing vault blob or KDF parameters'], 400);
}

$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);

$stmt = $db->prepare(
    'INSERT INTO vault_blobs (phone, blob, kdf_salt, kdf_params, version, updated_at)
     VALUES (:phone, :blob, :kdf_salt, :kdf_params, :version, :updated_at)
     ON CONFLICT(phone) DO UPDATE SET
        blob = excluded.blob,
        kdf_salt = excluded.kdf_salt,
        kdf_params = excluded.kdf_params,
        version = excluded.version,
        updated_at = excluded.updated_at'
);
$stmt->execute([
    ':phone' => $phone,
    ':blob' => $blob,
    ':kdf_salt' => $kdfSalt,
    ':kdf_params' => json_encode($kdfParams),
    ':version' => $version,
    ':updated_at' => $now,
]);

arif_kyla_send_json(['updatedAt' => $now]);
