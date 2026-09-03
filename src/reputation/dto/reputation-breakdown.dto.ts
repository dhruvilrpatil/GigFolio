/**
 * reputation-breakdown.dto.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Response DTO for GET /api/v1/reputation/breakdown.
 * Field names, nesting, and types match Section 3.6 exactly.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { ApiProperty } from '@nestjs/swagger';

export class ReputationSubscoresDto {
  @ApiProperty({ example: 0.91, description: 'Bayesian-adjusted volume-weighted platform rating [0,1]' })
  rating_vector: number;

  @ApiProperty({ example: 0.77, description: 'Logarithmic job-count saturation against domain benchmark [0,1]' })
  volume_vector: number;

  @ApiProperty({ example: 0.94, description: 'Non-linear completion rate score (completion_rate^3) [0,1]' })
  reliability_vector: number;

  @ApiProperty({ example: 0.68, description: '52-week activity continuity with recency decay [0,1]' })
  consistency_vector: number;

  @ApiProperty({ example: 0.50, description: 'Verified credentials weighted sum [0,1]' })
  skills_vector: number;
}

export class ReputationNormalizedMetricsDto {
  @ApiProperty({ example: 1240, description: 'Total verified completed jobs across all connected platforms' })
  total_verified_jobs: number;

  @ApiProperty({ example: 0.98, description: 'Ratio of completed to accepted jobs (N_completed / N_accepted)' })
  aggregate_completion_rate: number;

  @ApiProperty({ example: 3, description: 'Number of connected platforms with verified data' })
  active_platforms_count: number;
}

export class ReputationBreakdownResponseDto {
  @ApiProperty({ example: 782, description: 'Composite reputation score scaled to [300, 850]' })
  composite_score: number;

  @ApiProperty({ example: 0.86, description: 'Confidence index CI = 1 - exp(-N_total/50). Range [0,1]' })
  confidence_index: number;

  @ApiProperty({
    example: 'HIGH_CONFIDENCE',
    enum: ['LOW', 'MEDIUM', 'HIGH_CONFIDENCE'],
    description: 'Confidence tier. LOW: CI<0.40, MEDIUM: 0.40≤CI<0.75, HIGH_CONFIDENCE: CI≥0.75',
  })
  confidence_tier: string;

  @ApiProperty({ type: ReputationSubscoresDto })
  subscores: ReputationSubscoresDto;

  @ApiProperty({ type: ReputationNormalizedMetricsDto })
  normalized_metrics: ReputationNormalizedMetricsDto;
}
