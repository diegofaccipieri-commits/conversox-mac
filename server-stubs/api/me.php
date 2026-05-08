<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/auth.php';
require_once __DIR__ . '/../config/omnichannel_session_auth.php';
require_once __DIR__ . '/../config/conversox_acl.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('X-Content-Type-Options: nosniff');

function json_response(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

try {
    $apiKey = $_SERVER['HTTP_X_API_KEY'] ?? '';
    $authSource = $_SERVER['HTTP_X_CONVERSOX_AUTH_SOURCE'] ?? ($_COOKIE['CONVERSOX_AUTH_SOURCE'] ?? 'imigrando');

    if ($apiKey !== '') {
        // Replace this block with the same hashed lookup used by api/agent/client.php,
        // then resolve the owning user and apply that user's Conversox ACL.
        json_response([
            'ok' => false,
            'error' => 'api_key_user_resolution_not_implemented',
        ], 501);
    }

    omnichannel_auth_require_user(['api' => true]);
    $user = getCurrentUser();
    if (!$user) {
        json_response(['ok' => false, 'error' => 'unauthorized'], 401);
    }

    $email = $user['email'] ?? '';
    $connections = conversox_acl_user_connections($email);

    json_response([
        'ok' => true,
        'user' => [
            'id' => $user['id'] ?? null,
            'email' => $email,
            'name' => $user['name'] ?? ($user['full_name'] ?? $email),
            'role' => $user['role'] ?? 'viewer',
            'company_id' => $user['company_id'] ?? null,
            'auth_source' => $authSource,
            'session_remaining_seconds' => function_exists('getSessionRemainingSeconds')
                ? getSessionRemainingSeconds()
                : null,
        ],
        'conversox' => [
            'restricted' => empty($connections),
            'connections' => array_values($connections),
            'csrf_token' => $_SESSION['csrf_token'] ?? null,
        ],
    ]);
} catch (Throwable $e) {
    error_log('[ConversoxMac /api/me.php] ' . $e->getMessage());
    json_response(['ok' => false, 'error' => 'internal_error'], 500);
}
