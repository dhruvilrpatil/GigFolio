/**
 * reputation.controller.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * GET /api/v1/reputation/breakdown
 *
 * Auth: Bearer JWT (worker role). Scope: worker:reputation:read.
 * Rate limit: 30 req/min (enforced via Redis token-bucket throttler).
 *
 * Response shape is EXACTLY as specified in Section 3.6.
 * Field names, nesting, and types must not be altered.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Logger,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { ReputationService } from './reputation.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../common/guards/jwt-auth.guard';
import { ReputationBreakdownResponseDto } from './dto/reputation-breakdown.dto';
import { ReputationBreakdown } from './interfaces/reputation-result.interface';

@ApiTags('Reputation')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/reputation')
export class ReputationController {
  private readonly logger = new Logger(ReputationController.name);

  constructor(private readonly reputationService: ReputationService) {}

  /**
   * GET /api/v1/reputation/breakdown
   *
   * Returns the current reputation score breakdown for the authenticated worker.
   * Scope required: worker:reputation:read
   * Rate limit: 30 requests/minute per worker.
   */
  @Get('breakdown')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Get reputation breakdown',
    description:
      'Returns the composite reputation score and all five sub-vector scores for the authenticated worker. ' +
      'Scores are recalculated asynchronously after each platform data ingestion. ' +
      'Confidence tier reflects data volume: LOW (<25 jobs), MEDIUM (25-69 jobs), HIGH_CONFIDENCE (≥70 jobs).',
  })
  @ApiResponse({
    status: 200,
    description: 'Reputation breakdown retrieved successfully',
    type: ReputationBreakdownResponseDto,
  })
  @ApiResponse({ status: 401, description: 'Missing or invalid Bearer token' })
  @ApiResponse({ status: 404, description: 'No reputation score calculated yet for this worker' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (30 req/min)' })
  async getBreakdown(
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<ReputationBreakdownResponseDto> {
    this.checkScope(user, 'worker:reputation:read');

    const breakdown: ReputationBreakdown = await this.reputationService.getBreakdown(
      user.sub,
    );

    // ── Map to exact response shape (Section 3.6) ─────────────────────────────
    return {
      composite_score: breakdown.composite_score,
      confidence_index: breakdown.confidence_index,
      confidence_tier: breakdown.confidence_tier,
      subscores: {
        rating_vector: breakdown.rating_subscore,
        volume_vector: breakdown.volume_subscore,
        reliability_vector: breakdown.reliability_subscore,
        consistency_vector: breakdown.consistency_subscore,
        skills_vector: breakdown.skills_subscore,
      },
      normalized_metrics: {
        total_verified_jobs: breakdown.total_verified_jobs,
        aggregate_completion_rate: breakdown.aggregate_completion_rate,
        active_platforms_count: breakdown.active_platforms_count,
      },
    };
  }

  private checkScope(user: AuthenticatedUser, required: string): void {
    if (!user.scopes?.includes(required)) {
      const { ForbiddenException } = require('@nestjs/common');
      throw new ForbiddenException(
        `Insufficient scope. Required: ${required}`,
      );
    }
  }
}
