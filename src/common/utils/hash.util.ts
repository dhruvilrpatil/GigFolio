/**
 * hash.util.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Cryptographic hashing utilities for GigFolio.
 *
 * Design decisions:
 *  - SHA-256 is used for one-way token and IP hashing (lookup keys, audit).
 *    Raw tokens and raw IP addresses are NEVER stored; only their hashes are.
 *  - Argon2id is used for passcode hashing (optional share-link PINs).
 *    Argon2id is the recommended winner of the Password Hashing Competition and
 *    is resistant to both side-channel (Argon2i) and GPU brute-force (Argon2d).
 *  - All functions are pure and synchronous (SHA-256) or async (Argon2id) to
 *    keep the calling code honest about I/O boundaries.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { createHash } from 'crypto';
import * as argon2 from 'argon2';

// ── SHA-256 ───────────────────────────────────────────────────────────────────

/**
 * Returns the hex-encoded SHA-256 digest of `input`.
 * Used for: share token hashing, IP address hashing, consent artifact hashing.
 */
export function sha256Hex(input: string): string {
  return createHash('sha256').update(input, 'utf8').digest('hex');
}

// ── Argon2id ──────────────────────────────────────────────────────────────────

/**
 * Argon2id options per OWASP 2023 recommendation:
 *   memory: 64 MiB, iterations: 3, parallelism: 4
 */
const ARGON2_OPTIONS: argon2.Options & { raw?: false } = {
  type: argon2.argon2id,
  memoryCost: 65536,  // 64 MiB
  timeCost: 3,
  parallelism: 4,
};

/**
 * Hashes a passcode using Argon2id.
 * The resulting string includes the salt and algorithm parameters
 * (PHC format) so verification is self-contained.
 */
export async function hashPasscode(passcode: string): Promise<string> {
  return argon2.hash(passcode, ARGON2_OPTIONS);
}

/**
 * Verifies a plaintext passcode against an Argon2id hash.
 * Returns true if they match; false otherwise.
 * Never throws — catches and returns false on any error.
 */
export async function verifyPasscode(
  hash: string,
  passcode: string,
): Promise<boolean> {
  try {
    return await argon2.verify(hash, passcode);
  } catch {
    return false;
  }
}
