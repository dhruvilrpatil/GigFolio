/**
 * share-link.service.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Core share-link management service.
 *
 * Token security workflow (spec Section 4.5 — MANDATORY, NO EXCEPTIONS):
 *   1. generate cryptographically secure random token
 *   2. SHA-256 hash it
 *   3. store ONLY the hash in share_links.token_hash
 *   4. return the raw token to the caller exactly once
 *   5. never log, cache, or persist the raw token anywhere else
 *
 * Passcode security:
 *   - Optional passcode is hashed with Argon2id before storage.
 *   - Verification compares Argon2id(incoming) vs stored hash.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { InjectRedis } from '@nestjs-modules/ioredis';
import { DataSource, Repository } from 'typeorm';
import type { Redis } from 'ioredis';
import { ShareLink } from './entities/share-link.entity';
import { ConsentRecord } from './entities/consent-record.entity';
import { CreateShareLinkDto, MAX_TTL_HOURS, VALID_SCOPE_PREFIXES } from './dto/create-share-link.dto';
import { QrService } from './qr.service';
import { AuditService } from '../audit/audit.service';
import { generateSecureToken } from '../common/utils/crypto.util';
import { sha256Hex, hashPasscode } from '../common/utils/hash.util';

/** Redis key prefix for revocation propagation. */
const REVOCATION_KEY_PREFIX = 'share_link:revoked:';

/** App base URL for constructing share URLs. */
const APP_BASE_URL = process.env.APP_BASE_URL ?? 'https://gigfolio.io';

@Injectable()
export class ShareLinkService {
  private readonly logger = new Logger(ShareLinkService.name);

  constructor(
    @InjectRepository(ShareLink)
    private readonly shareLinkRepo: Repository<ShareLink>,
    @InjectRepository(ConsentRecord)
    private readonly consentRepo: Repository<ConsentRecord>,
    @InjectRedis() private readonly redis: Redis,
    private readonly qrService: QrService,
    private readonly auditService: AuditService,
    private readonly dataSource: DataSource,
  ) {}

  // ── Create Share Link ─────────────────────────────────────────────────────

  async create(
    workerId: string,
    dto: CreateShareLinkDto,
    correlationId: string,
    ipHash: string | null,
    userAgent: string | null,
  ): Promise<{
    shareToken: string;
    shareUrl: string;
    qrCodeSvgUrl: string;
    permittedScopes: string[];
    expiresAt: Date;
    linkId: string;
  }> {
    // Enforce 720-hour maximum TTL (spec Section 4.4 — hard limit)
    if (dto.ttl_hours > MAX_TTL_HOURS) {
      throw new BadRequestException(
        `ttl_hours cannot exceed ${MAX_TTL_HOURS} hours (30 days).`,
      );
    }

    // Validate scopes follow the known naming convention
    this.validateScopes(dto.permitted_scopes);

    // ── Token generation (spec Section 4.5) ───────────────────────────────
    // Step 1: generate cryptographically secure random token
    const rawToken = generateSecureToken();
    // Step 2: SHA-256 hash
    const tokenHash = sha256Hex(rawToken);
    // (Step 3 happens at DB insert below; rawToken is NOT stored)

    // ── Expiry ────────────────────────────────────────────────────────────
    const expiresAt = new Date();
    expiresAt.setTime(expiresAt.getTime() + dto.ttl_hours * 60 * 60 * 1000);

    // ── Passcode (optional) ───────────────────────────────────────────────
    const passcodeHash = dto.passcode
      ? await hashPasscode(dto.passcode)
      : null;

    // ── Persist share link (only hash stored — NEVER raw token) ───────────
    const shareLink = this.shareLinkRepo.create({
      worker_id: workerId,
      token_hash: tokenHash,
      permitted_scopes: dto.permitted_scopes,
      passcode_hash: passcodeHash,
      max_uses: dto.max_uses ?? null,
      current_uses: 0,
      expires_at: expiresAt,
      revoked_at: null,
    });
    await this.shareLinkRepo.save(shareLink);

    // ── Build share URL and QR ────────────────────────────────────────────
    const shareUrl = `${APP_BASE_URL}/verify/${rawToken}`;
    const qrCodeSvgUrl = await this.qrService.generateQrCodeUrl(shareUrl, rawToken);

    // ── Audit: SHARE_LINK_CREATED ─────────────────────────────────────────
    await this.auditService.emit({
      actor_id: workerId,
      actor_role: 'worker',
      action: 'SHARE_LINK_CREATED',
      target_worker_id: workerId,
      accessed_scopes: dto.permitted_scopes,
      ip_address_hash: ipHash,
      user_agent: userAgent,
      correlation_id: correlationId,
    });

    // Step 4: Return raw token exactly once (never logged, never stored)
    return {
      shareToken: rawToken,
      shareUrl,
      qrCodeSvgUrl,
      permittedScopes: dto.permitted_scopes,
      expiresAt,
      linkId: shareLink.id,
    };
  }

  // ── Revoke Share Link ─────────────────────────────────────────────────────

  async revoke(
    shareLinkId: string,
    workerId: string,
    correlationId: string,
    ipHash: string | null,
    userAgent: string | null,
  ): Promise<{ revokedAt: Date }> {
    const shareLink = await this.shareLinkRepo.findOne({
      where: { id: shareLinkId, worker_id: workerId },
    });

    if (!shareLink) {
      throw new NotFoundException(
        `Share link ${shareLinkId} not found or does not belong to this worker.`,
      );
    }

    if (shareLink.revoked_at) {
      throw new BadRequestException('Share link is already revoked.');
    }

    const revokedAt = new Date();

    // Transactional revoke: mark in DB + propagate to Redis immediately
    await this.dataSource.transaction(async (manager) => {
      await manager.update(ShareLink, shareLinkId, { revoked_at: revokedAt });
    });

    // Propagate revocation to Redis cache for immediate effect
    // (so verification fails even if an in-flight request still has a cached token)
    await this.redis.setex(
      `${REVOCATION_KEY_PREFIX}${shareLink.token_hash}`,
      60 * 60 * 24 * 31, // 31 days TTL > max link TTL
      '1',
    );

    // ── Audit: SHARE_LINK_REVOKED ─────────────────────────────────────────
    await this.auditService.emit({
      actor_id: workerId,
      actor_role: 'worker',
      action: 'SHARE_LINK_REVOKED',
      target_worker_id: workerId,
      accessed_scopes: shareLink.permitted_scopes,
      ip_address_hash: ipHash,
      user_agent: userAgent,
      correlation_id: correlationId,
    });

    return { revokedAt };
  }

  // ── Token Resolution (used by VerificationService) ────────────────────────

  async resolveToken(rawToken: string): Promise<ShareLink | null> {
    const tokenHash = sha256Hex(rawToken);

    // Check Redis revocation cache first (O(1), avoids DB round-trip)
    const isRevoked = await this.redis.exists(
      `${REVOCATION_KEY_PREFIX}${tokenHash}`,
    );
    if (isRevoked) return null;

    return this.shareLinkRepo.findOne({
      where: { token_hash: tokenHash },
      relations: ['consent_record'],
    });
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  private validateScopes(scopes: string[]): void {
    for (const scope of scopes) {
      const valid = VALID_SCOPE_PREFIXES.some((prefix) =>
        scope.startsWith(prefix),
      );
      if (!valid) {
        throw new BadRequestException(
          `Invalid scope: "${scope}". Must start with one of: ${VALID_SCOPE_PREFIXES.join(', ')}`,
        );
      }
    }
  }
}
