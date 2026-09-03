/**
 * audit-event.dto.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Internal DTO for emitting audit events.
 * Maps to the access_audit_logs table owned by Developer 1.
 * Raw IP addresses MUST NOT be passed here — hash before calling.
 * ─────────────────────────────────────────────────────────────────────────────
 */

export type AuditAction =
  | 'SHARE_LINK_CREATED'
  | 'SHARE_LINK_REVOKED'
  | 'VERIFICATION_ATTEMPT'
  | 'VERIFICATION_SUCCEEDED'
  | 'VERIFICATION_FAILED'
  | 'CREDENTIAL_PRESENTATION_ISSUED'
  | 'CONSENT_GRANTED'
  | 'CONSENT_MODIFIED'
  | 'CONSENT_REVOKED'
  | 'REPUTATION_RECALCULATED'
  | 'PUBLIC_PROFILE_VIEWED'
  | 'PUBLIC_ID_ROTATED';

export type AuditActorRole =
  | 'worker'
  | 'organization'
  | 'system'
  | 'admin';

export interface AuditEventDto {
  /** Worker UUID, or null for anonymous public-token access. */
  actor_id: string | null;
  actor_role: AuditActorRole;
  action: AuditAction;
  target_worker_id: string;
  accessed_scopes: string[];
  /**
   * SHA-256 hash of the requester IP. NEVER the raw IP.
   * Null if IP is unavailable (e.g., internal system calls).
   */
  ip_address_hash: string | null;
  user_agent: string | null;
  /** UUID v4 for distributed tracing correlation. */
  correlation_id: string;
}
