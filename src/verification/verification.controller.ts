/**
 * verification.controller.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * POST /api/v1/organizations/verify-worker
 *
 * Auth: X-Organization-Key header (not a worker JWT).
 * Rate limit: 120 req/min.
 *
 * Exact error semantics (spec Section 6.1 — MUST match):
 *   401 — invalid/missing organization API key
 *   403 — wrong passcode, or consent revoked/does not authorize access
 *   410 — token expired OR usage limit exhausted
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Logger,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiHeader,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Request } from 'express';
import { VerificationService } from './verification.service';
import { OrgApiKeyGuard } from '../common/guards/org-api-key.guard';
import { CurrentOrg } from '../common/decorators/current-org.decorator';
import { OrganizationContext } from '../common/guards/org-api-key.guard';
import { AuditService } from '../audit/audit.service';
import { VerifyWorkerRequestDto, VerifyWorkerResponseDto } from './dto/verify-worker.dto';
import { generateCorrelationId } from '../common/utils/crypto.util';

@ApiTags('Enterprise Verification')
@UseGuards(OrgApiKeyGuard)
@Controller('api/v1/organizations')
export class VerificationController {
  private readonly logger = new Logger(VerificationController.name);

  constructor(private readonly verificationService: VerificationService) {}

  /**
   * POST /api/v1/organizations/verify-worker
   *
   * Resolves a share token and returns only the consented worker data fields
   * packaged in an SD-JWT presentation. All sensitive fields not explicitly
   * consented are excluded from the response.
   *
   * Rate limit: 120 req/min per organization API key.
   */
  @Post('verify-worker')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Enterprise worker verification',
    description:
      'Verifies a worker using a share token. Returns ONLY the fields the worker ' +
      'has consented to share. All verification events are recorded in the immutable audit log. ' +
      'Requires X-Organization-Key header with org:verification:consume scope.',
  })
  @ApiHeader({
    name: 'X-Organization-Key',
    description: 'Organization API key with org:verification:consume scope.',
    required: true,
  })
  @ApiResponse({
    status: 200,
    description: 'Verification successful — consented data returned',
    type: VerifyWorkerResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Invalid or missing X-Organization-Key header',
  })
  @ApiResponse({
    status: 403,
    description: 'Wrong passcode, or consent revoked/does not authorize this access',
  })
  @ApiResponse({
    status: 410,
    description: 'Token expired or usage limit already exhausted',
  })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (120 req/min)' })
  async verifyWorker(
    @Body() dto: VerifyWorkerRequestDto,
    @CurrentOrg() org: OrganizationContext,
    @Req() req: Request,
  ): Promise<VerifyWorkerResponseDto> {
    const ipHash = AuditService.hashIp(req.ip);
    const userAgent = req.headers['user-agent'] ?? null;

    const result = await this.verificationService.verify(
      dto.share_token,
      dto.access_passcode,
      dto.verifier_nonce,
      org.id,
      org.name,
      ipHash,
      userAgent,
      dto.worker_public_id,   // optional public-ID binding
    );

    return {
      verification_event_id: result.verification_event_id,
      worker: result.worker,
      verification_tier: result.verification_tier,
      verified_metrics: result.verified_metrics,
      sd_jwt_presentation: result.sd_jwt_presentation,
    };
  }
}
