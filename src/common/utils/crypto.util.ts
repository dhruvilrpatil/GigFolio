/**
 * crypto.util.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Cryptographically secure random token generation.
 *
 * Design decisions:
 *  - Uses Node.js `crypto.randomBytes` (CSPRNG) — never Math.random().
 *  - Tokens are base64url-encoded (URL-safe, no padding) so they can be
 *    embedded directly in URLs without additional encoding.
 *  - 32 bytes = 256 bits of entropy — sufficient for bearer tokens that
 *    expire within 720 hours and are single-use.
 *  - The raw token is returned to the caller exactly once; callers are
 *    responsible for hashing before persistence (see hash.util.ts).
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { randomBytes } from 'crypto';

const TOKEN_BYTE_LENGTH = 32; // 256 bits

/**
 * Generates a cryptographically secure random token.
 * Returns base64url encoding (URL-safe, no `=` padding).
 *
 * IMPORTANT: The returned string is a raw secret.
 *   - Return it to the client exactly once.
 *   - Hash it with sha256Hex() before storing in the database.
 *   - Never log it.
 */
export function generateSecureToken(): string {
  return randomBytes(TOKEN_BYTE_LENGTH).toString('base64url');
}

/**
 * Generates a UUID v4-compatible correlation ID for distributed tracing.
 * Uses crypto.randomUUID (Node 14.17+).
 */
export function generateCorrelationId(): string {
  return crypto.randomUUID();
}
