/**
 * consent.controller.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * POST /api/v1/consent/share-links   — create a share link with QR
 * DELETE /api/v1/consent/share-links/{id} — revoke a share link
 *
 * Auth: Bearer JWT (worker role).
 * Rate limits enforced via throttler decorators.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
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
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Request } from 'express';
import { ShareLinkService } from './share-link.service';
import { CreateShareLinkDto } from './dto/create-share-link.dto';
import { ShareLinkResponseDto, RevokeLinkResponseDto } from './dto/share-link-response.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, } from '../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../common/guards/jwt-auth.guard';
import { AuditService } from '../audit/audit.service';
import { generateCorrelationId } from '../common/utils/crypto.util';

@ApiTags('Consent & Share Links')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/consent')
export class ConsentController {
  private readonly logger = new Logger(ConsentController.name);

  constructor(
    private readonly shareLinkService: ShareLinkService,
    private readonly auditService: AuditService,
  ) {}

  /**
   * POST /api/v1/consent/share-links
   *
   * Creates a time-boxed, scope-limited share link with optional passcode and QR code.
   * Auth: worker:consent:write scope required.
   * Rate limit: 20 req/hour.
   *
   * CRITICAL: share_token in the response is shown EXACTLY ONCE.
   * The worker must distribute it immediately — it cannot be retrieved again.
   */
  @Post('share-links')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Create share link with QR code',
    description:
      'Creates a cryptographically secure share link. The share_token is shown ONLY ONCE in this response. ' +
      'TTL maximum is 720 hours. Scopes must follow identity:/earnings:/reputation: naming convention.',
  })
  @ApiResponse({
    status: 201,
    description: 'Share link created successfully',
    type: ShareLinkResponseDto,
  })
  @ApiResponse({ status: 400, description: 'Invalid scopes or TTL > 720 hours' })
  @ApiResponse({ status: 401, description: 'Missing or invalid Bearer token' })
  @ApiResponse({ status: 403, description: 'Worker account unverified or insufficient scope' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (20 req/hour)' })
  async createShareLink(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateShareLinkDto,
    @Req() req: Request,
  ): Promise<ShareLinkResponseDto> {
    this.checkScope(user, 'worker:consent:write');
    this.checkVerified(user);

    const correlationId = generateCorrelationId();
    const ipHash = AuditService.hashIp(req.ip);
    const userAgent = req.headers['user-agent'] ?? null;

    const result = await this.shareLinkService.create(
      user.sub,
      dto,
      correlationId,
      ipHash,
      userAgent,
    );

    return {
      share_token: result.shareToken,  // ← Raw token, shown once only
      share_url: result.shareUrl,
      qr_code_svg_url: result.qrCodeSvgUrl,
      permitted_scopes: result.permittedScopes,
      expires_at: result.expiresAt.toISOString(),
    };
  }

  /**
   * DELETE /api/v1/consent/share-links/{id}
   *
   * Revokes a share link immediately. Propagates to Redis cache and the
   * credential status registry. Auth: worker:consent:delete scope required.
   * Rate limit: 60 req/min.
   */
  @Delete('share-links/:id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Revoke share link',
    description:
      'Immediately revokes a share link. Revocation is propagated to Redis so it takes ' +
      'effect on the next verification attempt without waiting for a DB read.',
  })
  @ApiParam({ name: 'id', description: 'UUID of the share link to revoke' })
  @ApiResponse({
    status: 200,
    description: 'Share link revoked',
    type: RevokeLinkResponseDto,
  })
  @ApiResponse({ status: 401, description: 'Missing or invalid Bearer token' })
  @ApiResponse({ status: 403, description: 'Insufficient scope or link not owned by this worker' })
  @ApiResponse({ status: 404, description: 'Share link not found' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (60 req/min)' })
  async revokeShareLink(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') linkId: string,
    @Req() req: Request,
  ): Promise<RevokeLinkResponseDto> {
    this.checkScope(user, 'worker:consent:delete');

    const correlationId = generateCorrelationId();
    const ipHash = AuditService.hashIp(req.ip);
    const userAgent = req.headers['user-agent'] ?? null;

    const { revokedAt } = await this.shareLinkService.revoke(
      linkId,
      user.sub,
      correlationId,
      ipHash,
      userAgent,
    );

    return {
      message: 'Share link revoked successfully.',
      revoked_at: revokedAt.toISOString(),
    };
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  private checkScope(user: AuthenticatedUser, required: string): void {
    if (!user.scopes?.includes(required)) {
      throw new ForbiddenException(`Insufficient scope. Required: ${required}`);
    }
  }

  private checkVerified(user: AuthenticatedUser): void {
    if (!user.is_verified) {
      throw new ForbiddenException(
        'Worker account must be verified before creating share links.',
      );
    }
  }
}
