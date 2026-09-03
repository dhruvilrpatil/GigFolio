/**
 * verification.service.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Enterprise verification pipeline (spec Section 6.2):
 *
 * 1. Token resolution   — SHA-256 lookup, validate active/unexpired/within limits
 * 2. Scope evaluation   — load permitted_scopes from consent_records
 * 3. Data projection    — query worker data, apply scope mask (ProjectionService)
 * 4. Presentation       — call CredentialPresentationService (never re-implement)
 * 5. Audit logging      — record event with hashed IP, scopes, correlation ID
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  ForbiddenException,
  GoneException,
  Inject,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { ShareLink } from '../consent/entities/share-link.entity';
import { ProjectionService, RawWorkerData } from './projection.service';
import { AuditService } from '../audit/audit.service';
import { ShareLinkService } from '../consent/share-link.service';
import {
  CREDENTIAL_PRESENTATION_SERVICE,
  ICredentialPresentationService,
} from '../credential/interfaces/credential-presentation.service.interface';
import { verifyPasscode } from '../common/utils/hash.util';
import { generateCorrelationId } from '../common/utils/crypto.util';

export interface VerificationResult {
  verification_event_id: string;
  worker: Record<string, unknown>;
  verification_tier: string;
  verified_metrics: Record<string, unknown>;
  sd_jwt_presentation: string;
}

@Injectable()
export class VerificationService {
  private readonly logger = new Logger(VerificationService.name);

  constructor(
    private readonly shareLinkService: ShareLinkService,
    private readonly projectionService: ProjectionService,
    private readonly auditService: AuditService,
    @Inject(CREDENTIAL_PRESENTATION_SERVICE)
    private readonly credentialService: ICredentialPresentationService,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async verify(
    shareToken: string,
    accessPasscode: string | undefined,
    verifierNonce: string,
    organizationId: string,
    organizationName: string,
    ipHash: string | null,
    userAgent: string | null,
    workerPublicId?: string,   // optional public-ID binding (Section: portable ID pattern)
  ): Promise<VerificationResult> {
    const correlationId = generateCorrelationId();

    // ── Step 1: Token Resolution ──────────────────────────────────────────────
    const shareLink = await this.shareLinkService.resolveToken(shareToken);

    if (!shareLink) {
      await this.emitFailedVerification(
        organizationId, null, [], ipHash, userAgent, correlationId,
        'Token not found or revoked',
      );
      // Return 410 for revoked/not-found (could also be 404, but 410 for consumed links)
      throw new GoneException('Share token is invalid, revoked, or expired.');
    }

    if (shareLink.revoked_at) {
      await this.emitFailedVerification(
        organizationId, shareLink.worker_id, shareLink.permitted_scopes,
        ipHash, userAgent, correlationId, 'Token revoked',
      );
      throw new GoneException('Share token has been revoked by the worker.');
    }

    if (shareLink.expires_at < new Date()) {
      await this.emitFailedVerification(
        organizationId, shareLink.worker_id, shareLink.permitted_scopes,
        ipHash, userAgent, correlationId, 'Token expired',
      );
      throw new GoneException('Share token has expired.');
    }

    if (
      shareLink.max_uses !== null &&
      shareLink.current_uses >= shareLink.max_uses
    ) {
      await this.emitFailedVerification(
        organizationId, shareLink.worker_id, shareLink.permitted_scopes,
        ipHash, userAgent, correlationId, 'Usage limit exhausted',
      );
      throw new GoneException('Share token usage limit has been exhausted.');
    }

    // ── Step 1b: Passcode check ───────────────────────────────────────────────
    if (shareLink.passcode_hash) {
      if (!accessPasscode) {
        await this.emitFailedVerification(
          organizationId, shareLink.worker_id, shareLink.permitted_scopes,
          ipHash, userAgent, correlationId, 'Missing passcode',
        );
        throw new ForbiddenException(
          'This share link requires an access passcode.',
        );
      }
      const passcodeValid = await verifyPasscode(
        shareLink.passcode_hash,
        accessPasscode,
      );
      if (!passcodeValid) {
        await this.emitFailedVerification(
          organizationId, shareLink.worker_id, shareLink.permitted_scopes,
          ipHash, userAgent, correlationId, 'Wrong passcode',
        );
        throw new ForbiddenException('Incorrect access passcode.');
      }
    }

    // ── Step 1c: Increment usage count (transactional) ────────────────────────
    await this.dataSource.query(
      `UPDATE share_links SET current_uses = current_uses + 1 WHERE id = $1`,
      [shareLink.id],
    );

    // ── Step 1d: Optional public_id binding check ─────────────────────────────
    // When the verifier supplies a worker_public_id (discovered via the public
    // lookup endpoint), we assert that the share_token belongs to a worker whose
    // public_id matches. This prevents cross-worker token confusion attacks.
    if (workerPublicId) {
      const bindingRows: Array<{ public_id: string }> = await this.dataSource.query(
        `SELECT public_id FROM workers WHERE id = $1`,
        [shareLink.worker_id],
      );
      const actualPublicId = bindingRows[0]?.public_id;
      if (actualPublicId !== workerPublicId) {
        await this.emitFailedVerification(
          organizationId, shareLink.worker_id, shareLink.permitted_scopes,
          ipHash, userAgent, correlationId,
          'worker_public_id binding mismatch',
        );
        throw new ForbiddenException(
          'The share token does not belong to the worker_public_id provided. ' +
            'Ensure you are using the correct token for this worker.',
        );
      }
    }

    // ── Step 2: Scope Evaluation ──────────────────────────────────────────────
    const permittedScopes = shareLink.permitted_scopes;

    // ── Step 3: Data Projection (scope-driven, not post-hoc strip) ────────────
    const rawData = await this.loadWorkerData(shareLink.worker_id);
    const projected = this.projectionService.project(rawData, permittedScopes);
    const workerResponse = this.projectionService.buildVerificationWorkerResponse(projected);
    const verifiedMetrics = this.projectionService.buildVerifiedMetrics(projected);

    // ── Step 4: Credential Presentation ──────────────────────────────────────
    // Build claims array from projected data
    const claims = Object.entries(projected).map(([key, value]) => {
      const namespace = key.includes('_') ? key.split('_')[0] : 'identity';
      return { namespace, key, value };
    });

    // Call CredentialPresentationService — NEVER re-implement signing here
    const sdJwtPresentation = await this.credentialService.assemblePresentation({
      claims,
      worker_data: projected,
      verifier_nonce: verifierNonce,
      consent_context: {
        consent_record_id: shareLink.consent_record_id ?? shareLink.id,
        share_link_id: shareLink.id,
        authorized_scopes: permittedScopes,
      },
    });

    // ── Step 5: Audit Logging ─────────────────────────────────────────────────
    const verificationEventId = generateCorrelationId();

    await this.auditService.emit({
      actor_id: organizationId,
      actor_role: 'organization',
      action: 'VERIFICATION_SUCCEEDED',
      target_worker_id: shareLink.worker_id,
      accessed_scopes: permittedScopes,
      ip_address_hash: ipHash,
      user_agent: userAgent,
      correlation_id: correlationId,
    });

    await this.auditService.emit({
      actor_id: organizationId,
      actor_role: 'organization',
      action: 'CREDENTIAL_PRESENTATION_ISSUED',
      target_worker_id: shareLink.worker_id,
      accessed_scopes: permittedScopes,
      ip_address_hash: ipHash,
      user_agent: userAgent,
      correlation_id: correlationId,
    });

    // Determine verification tier (simplified — full implementation uses
    // Developer 2's identity verification status)
    const verificationTier = this.resolveVerificationTier(rawData);

    return {
      verification_event_id: verificationEventId,
      worker: workerResponse,
      verification_tier: verificationTier,
      verified_metrics: verifiedMetrics,
      sd_jwt_presentation: sdJwtPresentation,
    };
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  private async emitFailedVerification(
    organizationId: string,
    workerId: string | null,
    scopes: string[],
    ipHash: string | null,
    userAgent: string | null,
    correlationId: string,
    reason: string,
  ): Promise<void> {
    this.logger.warn(`Verification failed: ${reason} | org=${organizationId}`);
    await this.auditService.emit({
      actor_id: organizationId,
      actor_role: 'organization',
      action: 'VERIFICATION_FAILED',
      target_worker_id: workerId ?? 'unknown',
      accessed_scopes: scopes,
      ip_address_hash: ipHash,
      user_agent: userAgent,
      correlation_id: correlationId,
    });
  }

  /**
   * Loads raw worker profile data from DB.
   * This is a projection query — only fields needed by any possible scope
   * are fetched. Sensitive fields (address, SSN, tokens, docs) are
   * NEVER selected here.
   */
  private async loadWorkerData(workerId: string): Promise<RawWorkerData> {
    // Only select the fields that could ever be in SCOPE_FIELD_MAP.
    // Address, phone, SSN, OAuth tokens, documents are deliberately omitted
    // from this query — they never enter the response pipeline.
    const rows = await this.dataSource.query(
      `
      SELECT
        w.legal_name,
        w.display_name,
        w.profile_photo_url,
        w.is_identity_verified,
        rs.composite_score,
        rs.confidence_tier,
        rs.confidence_index,
        rs.rating_subscore,
        rs.volume_subscore,
        rs.reliability_subscore,
        rs.consistency_subscore,
        rs.skills_subscore,
        (
          SELECT COALESCE(SUM(e.amount_usd), 0)
          FROM earnings_records e
          WHERE e.worker_id = w.id
            AND e.earned_at >= date_trunc('month', NOW())
        ) AS earnings_monthly_aggregate,
        'USD' AS currency,
        to_char(NOW(), 'YYYY-MM') AS earnings_period
      FROM workers w
      LEFT JOIN reputation_scores rs ON rs.worker_id = w.id
      WHERE w.id = $1
      `,
      [workerId],
    );

    const row = rows[0];
    if (!row) {
      return {};
    }

    // Load connected platforms
    const platformRows: Array<{ platform_id: string; is_verified: boolean }> =
      await this.dataSource.query(
        `SELECT platform_id, is_verified FROM platform_connections WHERE worker_id = $1`,
        [workerId],
      );

    return {
      legal_name: row.legal_name,
      display_name: row.display_name,
      profile_photo_url: row.profile_photo_url,
      is_identity_verified: row.is_identity_verified,
      composite_score: row.composite_score ? Number(row.composite_score) : undefined,
      confidence_tier: row.confidence_tier,
      confidence_index: row.confidence_index ? Number(row.confidence_index) : undefined,
      rating_subscore: row.rating_subscore ? Number(row.rating_subscore) : undefined,
      volume_subscore: row.volume_subscore ? Number(row.volume_subscore) : undefined,
      reliability_subscore: row.reliability_subscore ? Number(row.reliability_subscore) : undefined,
      consistency_subscore: row.consistency_subscore ? Number(row.consistency_subscore) : undefined,
      skills_subscore: row.skills_subscore ? Number(row.skills_subscore) : undefined,
      earnings_monthly_aggregate: Number(row.earnings_monthly_aggregate),
      currency: row.currency,
      earnings_period: row.earnings_period,
      connected_platforms: platformRows.map((p) => p.platform_id),
      platform_verification_status: Object.fromEntries(
        platformRows.map((p) => [p.platform_id, p.is_verified]),
      ),
    };
  }

  private resolveVerificationTier(data: RawWorkerData): string {
    if (data.is_identity_verified) return 'PLATFORM_VERIFIED';
    return 'SELF_REPORTED';
  }
}
