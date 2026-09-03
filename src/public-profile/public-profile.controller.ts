/**
 * public-profile.controller.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Two endpoints:
 *
 * 1. GET  /api/v1/public/workers/{worker_public_id}
 *    Auth: OrgApiKeyGuard (X-Organization-Key header)
 *    Returns ONLY non-sensitive discoverable fields. `worker_public_id` alone
 *    is a POINTER, not a bearer credential. Real data requires a share token.
 *
 * 2. POST /api/v1/workers/me/rotate-public-id
 *    Auth: JwtAuthGuard (worker Bearer JWT)
 *    Rotates the worker's public_id atomically. Old ID immediately invalidated.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Logger,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiHeader,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Request } from 'express';
import { PublicProfileService, DATA_ACCESS_HINT } from './public-profile.service';
import { OrgApiKeyGuard } from '../common/guards/org-api-key.guard';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentOrg } from '../common/decorators/current-org.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { OrganizationContext } from '../common/guards/org-api-key.guard';
import { AuthenticatedUser } from '../common/guards/jwt-auth.guard';
import { AuditService } from '../audit/audit.service';
import { generateCorrelationId } from '../common/utils/crypto.util';
import {
  PublicWorkerProfileDto,
  RotatePublicIdResponseDto,
} from './dto/public-profile.dto';

// ── Public Lookup Controller ───────────────────────────────────────────────────

@ApiTags('Public Worker Lookup')
@Controller('api/v1/public')
export class PublicProfileController {
  private readonly logger = new Logger(PublicProfileController.name);

  constructor(private readonly publicProfileService: PublicProfileService) {}

  /**
   * GET /api/v1/public/workers/{worker_public_id}
   *
   * Resolves a worker's public handle to the minimum discoverable profile.
   * This endpoint is a "pointer resolution" — it confirms the worker exists
   * on GigFolio and shows only fields the worker has opted to make visible.
   *
   * To access actual data: obtain a share token from the worker and call
   * POST /api/v1/organizations/verify-worker.
   *
   * Auth: X-Organization-Key header (OrgApiKeyGuard).
   * Rate limit: 120 req/min per organization key.
   */
  @Get('workers/:worker_public_id')
  @HttpCode(HttpStatus.OK)
  @UseGuards(OrgApiKeyGuard)
  @ApiHeader({
    name: 'X-Organization-Key',
    description: 'Organization API key with org:verification:consume scope.',
    required: true,
  })
  @ApiOperation({
    summary: 'Lookup worker by public ID',
    description:
      '**POINTER ONLY.** Resolves a `worker_public_id` to a minimal discoverable profile. ' +
      'Returns ONLY non-sensitive fields the worker has opted to disclose. ' +
      'The response never contains: address, phone, tax ID, earnings detail, raw scores, OAuth tokens. ' +
      '\n\nTo access actual data, obtain a **share token** from the worker and call ' +
      '`POST /api/v1/organizations/verify-worker` with it.',
  })
  @ApiParam({
    name: 'worker_public_id',
    description: 'The stable public UUID the worker shared (NOT their internal DB UUID)',
    schema: { type: 'string', format: 'uuid' },
  })
  @ApiResponse({
    status: 200,
    description: 'Public profile resolved',
    type: PublicWorkerProfileDto,
  })
  @ApiResponse({ status: 401, description: 'Invalid or missing X-Organization-Key' })
  @ApiResponse({ status: 404, description: 'No GigFolio profile found for this public ID' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (120 req/min)' })
  async getPublicProfile(
    @Param('worker_public_id') workerPublicId: string,
    @CurrentOrg() org: OrganizationContext,
    @Req() req: Request,
  ): Promise<PublicWorkerProfileDto> {
    const correlationId = generateCorrelationId();
    const ipHash = AuditService.hashIp(req.ip);
    const userAgent = req.headers['user-agent'] ?? null;

    const view = await this.publicProfileService.getPublicProfile(
      workerPublicId,
      org.id,
      ipHash,
      userAgent,
      correlationId,
    );

    return {
      worker_public_id: view.worker_public_id,
      display_name: view.display_name,
      is_identity_verified: view.is_identity_verified,
      has_reputation_score: view.has_reputation_score,
      verification_badge: view.verification_badge,
      data_access_hint: DATA_ACCESS_HINT,
    };
  }
}

// ── Worker Self-Service Controller ────────────────────────────────────────────

@ApiTags('Worker Settings')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/workers')
export class WorkerSettingsController {
  constructor(private readonly publicProfileService: PublicProfileService) {}

  /**
   * POST /api/v1/workers/me/rotate-public-id
   *
   * Regenerates the worker's public_id. The old ID is immediately invalidated —
   * any partner that cached it will receive 404 on next lookup.
   *
   * The internal worker_id (DB UUID), historical audit records, consent records,
   * and reputation scores are completely unaffected.
   *
   * Auth: Bearer JWT (worker role). Scope: worker:profile:write.
   * Rate limit: 5 req/hour (rotation is a sensitive operation).
   */
  @Post('me/rotate-public-id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Rotate worker public ID',
    description:
      'Generates a new `worker_public_id` and immediately invalidates the old one. ' +
      'Use this if your public ID has been shared with untrusted parties. ' +
      'Internal records (reputation, consent, audit history) are not affected.',
  })
  @ApiResponse({
    status: 200,
    description: 'Public ID rotated successfully',
    type: RotatePublicIdResponseDto,
  })
  @ApiResponse({ status: 401, description: 'Missing or invalid Bearer token' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (5 req/hour)' })
  async rotatePublicId(
    @CurrentUser() user: AuthenticatedUser,
    @Req() req: Request,
  ): Promise<RotatePublicIdResponseDto> {
    const correlationId = generateCorrelationId();
    const ipHash = AuditService.hashIp(req.ip);
    const userAgent = req.headers['user-agent'] ?? null;

    const result = await this.publicProfileService.rotatePublicId(
      user.sub,
      ipHash,
      userAgent,
      correlationId,
    );

    return {
      new_worker_public_id: result.newPublicId,
      previous_public_id: result.previousPublicId,
      rotated_at: result.rotatedAt.toISOString(),
    };
  }
}
