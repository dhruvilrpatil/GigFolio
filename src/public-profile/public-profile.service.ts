/**
 * public-profile.service.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Service for the portable worker public-ID lookup and rotation pattern.
 *
 * SECURITY INVARIANTS:
 *   1. `worker_public_id` alone returns ONLY non-sensitive, worker-controlled
 *      discoverable fields. It is a POINTER, not a bearer credential.
 *   2. Actual data (reputation score, earnings, identity) requires a valid
 *      consent-scoped share token via POST /api/v1/organizations/verify-worker.
 *   3. The internal `worker_id` (DB UUID) is NEVER exposed through this service.
 *   4. `public_id` rotation is atomic: the new UUID is set before the old one
 *      is considered invalid (no gap where neither resolves).
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { PublicWorkerView } from './entities/worker-public-profile.entity';
import { randomUUID } from 'crypto';

/** Immutable data-access hint returned in every public profile response. */
const DATA_ACCESS_HINT =
  'To access actual worker data (reputation, earnings, identity), obtain a ' +
  'share token from this worker and call POST /api/v1/organizations/verify-worker.';

@Injectable()
export class PublicProfileService {
  private readonly logger = new Logger(PublicProfileService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly auditService: AuditService,
  ) {}

  // ── Public Lookup ─────────────────────────────────────────────────────────

  /**
   * Resolves a worker_public_id to the minimal public profile view.
   *
   * Fields returned are strictly limited to worker-controlled "discoverable"
   * preferences. The internal worker_id is NEVER returned.
   *
   * @param publicId   - The public UUID from the URL param.
   * @param orgId      - Organization requesting the lookup (for audit).
   * @param ipHash     - SHA-256 of requester IP.
   * @param userAgent  - Requester user-agent string.
   * @param correlationId - Tracing correlation UUID.
   */
  async getPublicProfile(
    publicId: string,
    orgId: string,
    ipHash: string | null,
    userAgent: string | null,
    correlationId: string,
  ): Promise<PublicWorkerView> {
    // ── Query: join workers + reputation_scores + public_profiles ─────────────
    // We query ONLY fields relevant to public discovery.
    // Sensitive fields (address, phone, SSN, tokens, documents) are NEVER selected.
    const rows = await this.dataSource.query(
      `
      SELECT
        w.public_id                          AS worker_public_id,
        w.display_name,
        w.is_identity_verified,
        w.updated_at                         AS profile_updated_at,
        (rs.id IS NOT NULL)                  AS has_reputation_score,
        wpp.show_display_name,
        wpp.show_verification_badge,
        wpp.show_has_reputation
      FROM workers w
      LEFT JOIN reputation_scores    rs  ON rs.worker_id  = w.id
      LEFT JOIN worker_public_profiles wpp ON wpp.worker_id = w.id
      WHERE w.public_id = $1
      LIMIT 1
      `,
      [publicId],
    );

    if (!rows.length) {
      // Emit a failed lookup audit event before throwing
      await this.auditService.emit({
        actor_id: orgId,
        actor_role: 'organization',
        action: 'PUBLIC_PROFILE_VIEWED',
        target_worker_id: 'unknown',
        accessed_scopes: [],
        ip_address_hash: ipHash,
        user_agent: userAgent,
        correlation_id: correlationId,
      });
      throw new NotFoundException(
        `No GigFolio profile found for public ID: ${publicId}`,
      );
    }

    const row = rows[0];

    // Respect worker's disclosure preferences
    const showDisplayName   = row.show_display_name   !== false;
    const showBadge         = row.show_verification_badge !== false;
    const showHasReputation = row.show_has_reputation !== false;

    const badge = this.resolveBadge(row.is_identity_verified);

    // ── Audit: PUBLIC_PROFILE_VIEWED ──────────────────────────────────────────
    await this.auditService.emit({
      actor_id: orgId,
      actor_role: 'organization',
      action: 'PUBLIC_PROFILE_VIEWED',
      target_worker_id: row.worker_public_id, // safe: public ID, not internal UUID
      accessed_scopes: ['public:profile'],
      ip_address_hash: ipHash,
      user_agent: userAgent,
      correlation_id: correlationId,
    });

    return {
      worker_public_id: row.worker_public_id as string,
      display_name: showDisplayName ? (row.display_name as string | null) : null,
      is_identity_verified: row.is_identity_verified as boolean | null,
      has_reputation_score: showHasReputation
        ? (row.has_reputation_score as boolean)
        : false,
      verification_badge: showBadge ? badge : null,
      profile_updated_at: row.profile_updated_at
        ? (row.profile_updated_at as Date).toISOString()
        : null,
    };
  }

  // ── Public ID Rotation ─────────────────────────────────────────────────────

  /**
   * Rotates the worker's public_id atomically.
   *
   * The new UUID is assigned in the DB. Any external system that cached the
   * old public_id will receive a 404 on subsequent lookups, prompting them to
   * re-request the new ID from the worker. Historical records linked by the
   * internal worker_id are unaffected.
   *
   * @param workerId   - Internal worker UUID (from JWT — not exposed externally).
   * @param ipHash     - SHA-256 of requester IP for audit.
   * @param userAgent  - Requester user-agent string.
   * @param correlationId - Tracing correlation UUID.
   */
  async rotatePublicId(
    workerId: string,
    ipHash: string | null,
    userAgent: string | null,
    correlationId: string,
  ): Promise<{ previousPublicId: string; newPublicId: string; rotatedAt: Date }> {
    // Fetch current public_id to record in audit
    const currentRows = await this.dataSource.query(
      `SELECT public_id FROM workers WHERE id = $1`,
      [workerId],
    );
    if (!currentRows.length) {
      throw new NotFoundException('Worker not found.');
    }
    const previousPublicId = currentRows[0].public_id as string;

    // Generate a new cryptographically random UUID
    const newPublicId = randomUUID();
    const rotatedAt = new Date();

    // Atomic update — unique constraint guarantees no collision
    await this.dataSource.query(
      `UPDATE workers SET public_id = $1, updated_at = $2 WHERE id = $3`,
      [newPublicId, rotatedAt, workerId],
    );

    this.logger.log(
      `Worker ${workerId} rotated public_id: ${previousPublicId} → ${newPublicId}`,
    );

    // ── Audit: PUBLIC_ID_ROTATED ──────────────────────────────────────────────
    await this.auditService.emit({
      actor_id: workerId,
      actor_role: 'worker',
      action: 'PUBLIC_ID_ROTATED',
      target_worker_id: workerId,
      accessed_scopes: [],
      ip_address_hash: ipHash,
      user_agent: userAgent,
      correlation_id: correlationId,
    });

    return { previousPublicId, newPublicId, rotatedAt };
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  private resolveBadge(
    isVerified: boolean | null,
  ): 'VERIFIED' | 'PLATFORM_VERIFIED' | 'UNVERIFIED' | null {
    if (isVerified === true) return 'PLATFORM_VERIFIED';
    if (isVerified === false) return 'UNVERIFIED';
    return null;
  }
}

export { DATA_ACCESS_HINT };
