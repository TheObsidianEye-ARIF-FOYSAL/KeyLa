<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

$input = arif_kyla_json_input();
$phone = arif_kyla_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');

$db = arif_kyla_db();
arif_kyla_require_session($db, $phone, $token);

$stmt = $db->prepare('SELECT * FROM vault_blobs WHERE phone = ?');
$stmt->execute([$phone]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$row) {
    arif_kyla_send_json(['error' => 'No backup found'], 404);
}

arif_kyla_send_json([
    'blob' => $row['blob'],
    'kdfSalt' => $row['kdf_salt'],
    'kdfParams' => json_decode($row['kdf_params'], true),
    'version' => (int) $row['version'],
    'updatedAt' => $row['updated_at'],
]);
