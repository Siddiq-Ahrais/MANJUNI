<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserHasRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user || $user->is_active === false || ! in_array($user->role, $roles, true)) {
            abort(403, 'Anda tidak memiliki akses untuk tindakan ini.');
        }

        return $next($request);
    }
}
