/**
 * jwt-auth.guard.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Bearer JWT authentication guard.
 * Delegates actual JWT verification to Developer 1's AuthService.
 * This guard is a thin adapter: it extracts the token from the Authorization
 * header and attaches the decoded user to `request.user`.
 *
 * Integration note: Replace the `JwtService` stub import with Developer 1's
 * actual `@gigfolio/auth` module export when integrating the full monolith.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

export interface AuthenticatedUser {
  sub: string;           // worker UUID
  role: 'worker' | 'admin';
  scopes: string[];      // JWT-embedded scopes e.g. ['worker:reputation:read']
  email: string;
  is_verified: boolean;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<Request>();
    const token = this.extractBearerToken(request);

    if (!token) {
      throw new UnauthorizedException('Missing or malformed Authorization header');
    }

    try {
      // ── Integration point ─────────────────────────────────────────────────
      // In the full monolith, inject Developer 1's JwtService here and verify:
      //   const payload = await this.jwtService.verifyAsync(token);
      // For now, we decode without verification for local development only.
      // NEVER ship the stub to production.
      // ─────────────────────────────────────────────────────────────────────
      const payload = decodeJwtPayload(token);
      request['user'] = payload as AuthenticatedUser;
      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }

  private extractBearerToken(request: Request): string | null {
    const [type, token] = (request.headers.authorization ?? '').split(' ');
    return type === 'Bearer' && token ? token : null;
  }
}

/**
 * Development-only JWT payload decoder (no signature verification).
 * Replace with Developer 1's verified JwtService in production.
 */
function decodeJwtPayload(token: string): unknown {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Not a JWT');
  const payload = Buffer.from(parts[1], 'base64url').toString('utf8');
  return JSON.parse(payload);
}
