/**
 * reputation-result.interface.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Output shape of ReputationCalculator.
 * Maps 1:1 to reputation_scores table columns (owned by Developer 1).
 * ─────────────────────────────────────────────────────────────────────────────
 */

/** Confidence tier labels as required by spec Section 3.3 Step 5. */
export type ConfidenceTier = 'LOW' | 'MEDIUM' | 'HIGH_CONFIDENCE';

export interface ReputationResult {
  /** Composite score scaled to [300, 850]. smallint. */
  composite_score: number;

  /** Sub-vector values, each in [0, 1]. numeric(5,4). */
  rating_subscore: number;
  volume_subscore: number;
  reliability_subscore: number;
  consistency_subscore: number;
  skills_subscore: number;

  /** CI = 1 - exp(-N_total / 50). numeric(3,2). */
  confidence_index: number;

  /**
   * Confidence tier boundaries (judgment per Section 12):
   *   LOW            : CI < 0.40   (< ~25 total jobs)
   *   MEDIUM         : 0.40 ≤ CI < 0.75   (~25–69 total jobs)
   *   HIGH_CONFIDENCE: CI ≥ 0.75   (≥ ~69 total jobs)
   */
  confidence_tier: ConfidenceTier;

  /** ISO-8601 UTC timestamp of calculation. */
  calculated_at: Date;
}

/** Intermediate breakdown exposed to the REST layer (GET /reputation/breakdown). */
export interface ReputationBreakdown extends ReputationResult {
  /** Total verified jobs across all platforms. */
  total_verified_jobs: number;
  /** N_completed / N_accepted — aggregate completion rate. */
  aggregate_completion_rate: number;
  /** Count of distinct platform_ids with data. */
  active_platforms_count: number;
}
