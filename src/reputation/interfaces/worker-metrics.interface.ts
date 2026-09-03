/**
 * worker-metrics.interface.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Input contract from Developer 2's ingestion/normalization layer.
 * ReputationCalculator accepts this shape; Developer 2 populates it.
 * ─────────────────────────────────────────────────────────────────────────────
 */

/** One platform's normalized performance data (post-ingestion). */
export interface PlatformMetrics {
  /** Platform identifier, e.g. 'uber', 'doordash', 'upwork' */
  platform_id: string;

  /**
   * Observed mean of normalized ratings on this platform.
   * Already scaled to [0,1] by Developer 2's normalization layer.
   * (e.g., Uber 4.8/5.0 → 0.96; Upwork JSS 92% → 0.92)
   */
  normalized_mean_rating: number;

  /** Number of verified reviews/ratings on this platform. */
  verified_review_count: number;
}

/** Active week indicator for the 52-week consistency window. */
export interface WeeklyActivity {
  /** Week index: 1 = oldest week, 52 = most recent week. */
  week: number;
  /** true if there was verified platform activity in this week. */
  active: boolean;
}

/** A single verified skill/certification. */
export interface SkillCredential {
  /** Unique identifier for the skill/certification type. */
  skill_id: string;
  /** Relative importance weight assigned to this skill (0–1 scale). */
  weight: number;
  /** Whether this credential has been independently verified (V_j). */
  is_verified: boolean;
}

/**
 * Complete normalized metrics for a single worker.
 * This is the full input to ReputationCalculator.
 */
export interface WorkerMetrics {
  worker_id: string;

  /** Per-platform performance data. */
  platforms: PlatformMetrics[];

  /** Total jobs accepted (denominator for reliability). */
  total_jobs_accepted: number;

  /** Total jobs completed (numerator for reliability). */
  total_jobs_completed: number;

  /**
   * 52-week activity window.
   * Must contain exactly 52 entries (weeks 1–52).
   * Developer 2 provides this from aggregated job timestamps.
   */
  weekly_activity: WeeklyActivity[];

  /** Verified skills/certifications. */
  skills: SkillCredential[];

  /**
   * Worker's domain/vertical category.
   * Used to look up domain-specific N_target for the volume vector.
   * e.g. 'transport', 'freelance', 'home_services', 'delivery'
   */
  domain: string;
}
