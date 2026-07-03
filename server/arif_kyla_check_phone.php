<?php

require __DIR__ . '/arif_kyla_db.php';
arif_kyla_cors();

$input = arif_kyla_json_input();
$phone = arif_kyla_normalize_phone((string) ($input['phone'] ?? ''));

if (strlen($phone) !== 11) {
    arif_kyla_send_json(['error' => 'Enter a valid 11-digit phone number'], 400);
}

$db = arif_kyla_db();
$stmt = $db->prepare('SELECT 1 FROM users WHERE phone = ?');
$stmt->execute([$phone]);

arif_kyla_send_json(['exists' => (bool) $stmt->fetchColumn()]);
