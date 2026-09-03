/**
 * reputation-calculator.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * PURE, INDEPENDENTLY UNIT-TESTABLE reputation scoring engine.
 *
 * HARD REQUIREMENTS (Section 2 & 3.2):
 *   - Zero database dependencies.
 *   - Zero HTTP dependencies.
 *   - Zero NestJS module/DI coupling.
 *   - All formula constants are IMMUTABLE and match Section 3.3 exactly.
 *   - All formulas are self-contained within this class.
 *   - Developer 2 and test suites may import this class directly with no setup.
 *
 * Mathematical reference: Section 3.3 of the GigFolio Dev3 Build Spec.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { WorkerMetrics } from './interfaces/worker-metrics.interface';
import {
  ConfidenceTier,
  ReputationBreakdown,
  ReputationResult,
} from './interfaces/reputation-result.interface';

// ── Formula Constants (DO NOT MODIFY — binding per spec Section 12) ───────────

/** Bayesian prior mean (empirical industry baseline). */
const PRIOR_MEAN = 0.85; // m_p

/** Bayesian prior weight / confidence threshold in review-count units. */
const PRIOR_WEIGHT = 25; // C_p

/** Reliability exponent (non-linear penalty for cancellations). */
const RELIABILITY_EXPONENT = 3.0; // γ

/** 52-week consistency window length. */
const CONSISTENCY_WEEKS = 52; // T

/** Exponential decay half-life (weeks) for consistency scoring. */
const CONSISTENCY_HALF_LIFE = 26; // T_half

/** Composite index weights [w1..w5]. Must sum to 1.0. */
const WEIGHTS = {
  rating: 0.35,
  volume: 0.20,
  reliability: 0.25,
  consistency: 0.10,
  skills: 0.10,
} as const;

/** Score range endpoints for the [300, 850] scaled score. */
const SCORE_MIN = 300;
const SCORE_RANGE = 550; // 850 - 300

/**
 * Confidence index threshold for the Provisional Baseline flag.
 * Spec: if N_total < 5, force CI < 0.10.
 * CI = 1 - exp(-5/50) ≈ 0.0952 — already < 0.10, so the formula is naturally
 * compliant. We still hard-enforce the flag separately for clarity.
 */
const PROVISIONAL_BASELINE_MAX_JOBS = 5;

/**
 * Confidence tier cut points (Section 12 judgment):
 *   LOW            : CI < 0.40
 *   MEDIUM         : 0.40 ≤ CI < 0.75
 *   HIGH_CONFIDENCE: CI ≥ 0.75
 *
 * Derivation from CI = 1 - exp(-N/50):
 *   CI = 0.40 → N ≈ 25.5 jobs
 *   CI = 0.75 → N ≈ 69.3 jobs
 */
const CI_THRESHOLD_MEDIUM = 0.40;
const CI_THRESHOLD_HIGH = 0.75;

// ── Domain N_target Configuration ─────────────────────────────────────────────
// Configurable per worker vertical (Section 3.3 Step 2, Section 12).
// Add new domains here; no caller needs to know about these.
const DOMAIN_N_TARGETS: Record<string, number> = {
  transport: 1000,   // e.g., rideshare/delivery trips
  freelance: 50,     // e.g., Upwork contracts
  home_services: 200,
  delivery: 500,
  default: 200,      // fallback for unknown domains
};

// ── Main Calculator Class ──────────────────────────────────────────────────────

/**
 * ReputationCalculator — stateless, pure computation class.
 *
 * Usage:
 *   const calc = new ReputationCalculator();
 *   const result = calc.compute(workerMetrics);
 *
 * This class may be used in any context: NestJS services, CLI scripts,
 * unit tests, or Developer 2's ingestion pipeline — no setup required.
 */
export class ReputationCalculator {
  // ── Public API ─────────────────────────────────────────────────────────────

  /**
   * Computes the full reputation breakdown for a worker.
   *
   * @param metrics - Normalized worker metrics from Developer 2's layer.
   * @returns Full reputation result including all sub-vectors, composite score,
   *          confidence index, confidence tier, and normalized metric summaries.
   */
  compute(metrics: WorkerMetrics): ReputationBreakdown {
    const N_total = this.totalJobs(metrics);
    const nTarget = this.resolveNTarget(metrics.domain);

    // ── Sub-vectors (all clamped to [0, 1]) ──────────────────────────────────
    const S_rating = this.ratingVector(metrics.platforms);
    const S_volume = this.volumeVector(N_total, nTarget);
    const S_reliability = this.reliabilityVector(
      metrics.total_jobs_completed,
      metrics.total_jobs_accepted,
    );
    const S_consistency = this.consistencyVector(metrics.weekly_activity);
    const S_skills = this.skillsVector(metrics.skills);

    // ── Composite index ───────────────────────────────────────────────────────
    const I_composite =
      WEIGHTS.rating * S_rating +
      WEIGHTS.volume * S_volume +
      WEIGHTS.reliability * S_reliability +
      WEIGHTS.consistency * S_consistency +
      WEIGHTS.skills * S_skills;

    // ── Scaled score R = round(300 + 550 * I) — clamped to [300, 850] ────────
    const R_score = Math.round(SCORE_MIN + SCORE_RANGE * I_composite);
    const composite_score = Math.max(300, Math.min(850, R_score));

    // ── Confidence index ──────────────────────────────────────────────────────
    const confidence_index = this.confidenceIndex(N_total);
    const confidence_tier = this.confidenceTier(confidence_index);

    // ── Summaries for REST layer ──────────────────────────────────────────────
    const aggregate_completion_rate =
      metrics.total_jobs_accepted > 0
        ? metrics.total_jobs_completed / metrics.total_jobs_accepted
        : 0;

    return {
      composite_score,
      rating_subscore: this.clamp01(S_rating),
      volume_subscore: this.clamp01(S_volume),
      reliability_subscore: this.clamp01(S_reliability),
      consistency_subscore: this.clamp01(S_consistency),
      skills_subscore: this.clamp01(S_skills),
      confidence_index: parseFloat(confidence_index.toFixed(2)),
      confidence_tier,
      calculated_at: new Date(),
      total_verified_jobs: N_total,
      aggregate_completion_rate: parseFloat(aggregate_completion_rate.toFixed(4)),
      active_platforms_count: metrics.platforms.length,
    };
  }

  // ── Sub-vector Implementations ────────────────────────────────────────────

  /**
   * Step 2 — Bayesian shrinkage (m-estimate) for a single platform.
   *
   * Formula: μ̂_p = (C_p * m_p + N_p * x̄_p) / (C_p + N_p)
   *
   * Low-volume platforms shrink toward m_p = 0.85.
   * High-volume platforms converge to x̄_p (observed mean).
   */
  bayesianShrinkage(
    normalizedMeanRating: number,
    reviewCount: number,
  ): number {
    return (
      (PRIOR_WEIGHT * PRIOR_MEAN + reviewCount * normalizedMeanRating) /
      (PRIOR_WEIGHT + reviewCount)
    );
  }

  /**
   * Step 3a — Rating vector: volume-weighted average of shrunk per-platform means.
   *
   * Formula: S_rating = Σ_p (N_p / Σ_j N_j) * μ̂_p
   */
  ratingVector(
    platforms: WorkerMetrics['platforms'],
  ): number {
    if (platforms.length === 0) return PRIOR_MEAN; // no data → prior

    const totalReviews = platforms.reduce(
      (sum, p) => sum + p.verified_review_count,
      0,
    );

    if (totalReviews === 0) return PRIOR_MEAN;

    return platforms.reduce((sum, p) => {
      const weight = p.verified_review_count / totalReviews;
      const shrunk = this.bayesianShrinkage(
        p.normalized_mean_rating,
        p.verified_review_count,
      );
      return sum + weight * shrunk;
    }, 0);
  }

  /**
   * Step 3b — Volume vector: logarithmic saturation against domain benchmark.
   *
   * Formula: S_volume = min(1.0, ln(1 + N_total) / ln(1 + N_target))
   */
  volumeVector(N_total: number, N_target: number): number {
    if (N_target <= 0) return 0;
    return Math.min(1.0, Math.log(1 + N_total) / Math.log(1 + N_target));
  }

  /**
   * Step 3c — Reliability vector: non-linear penalty on cancellations.
   *
   * Formula: S_reliability = (N_completed / N_accepted) ^ γ, γ = 3.0
   *
   * Sanity checks (must hold):
   *   98% completion → 0.941 ✓  (0.98^3 = 0.9412)
   *   85% completion → 0.614 ✓  (0.85^3 = 0.6141)
   *
   * A 13-point completion drop (0.98→0.85) causes a ~35% reliability
   * score drop (0.941→0.614), as required by spec.
   */
  reliabilityVector(N_completed: number, N_accepted: number): number {
    if (N_accepted <= 0) return 0;
    const completionRate = N_completed / N_accepted;
    return Math.pow(completionRate, RELIABILITY_EXPONENT);
  }

  /**
   * Step 3d — Consistency vector: activity continuity with exponential recency decay.
   *
   * Formula:
   *   λ(t) = 2 ^ (-(T - t) / T_half)
   *   S_consistency = (1/T) * Σ_{t=1}^{T} w_t * λ(t)
   *
   * where w_t ∈ {0,1} indicates verified activity in week t,
   * T = 52, T_half = 26.
   *
   * Weights are normalized by T (not by Σλ) per spec formula.
   */
  consistencyVector(weeklyActivity: WorkerMetrics['weekly_activity']): number {
    // Build a week→active lookup for O(1) access.
    const activityMap = new Map<number, boolean>();
    for (const { week, active } of weeklyActivity) {
      activityMap.set(week, active);
    }

    let sum = 0;
    for (let t = 1; t <= CONSISTENCY_WEEKS; t++) {
      const w_t = activityMap.get(t) ? 1 : 0;
      const lambda_t = Math.pow(
        2,
        -(CONSISTENCY_WEEKS - t) / CONSISTENCY_HALF_LIFE,
      );
      sum += w_t * lambda_t;
    }
    return sum / CONSISTENCY_WEEKS;
  }

  /**
   * Step 3e — Skills vector: verified credential weighted sum.
   *
   * Formula: S_skills = min(1.0, Σ_j ω_j * V_j)
   * V_j ∈ {0,1}, ω_j = skill weight.
   */
  skillsVector(skills: WorkerMetrics['skills']): number {
    const raw = skills.reduce(
      (sum, s) => sum + s.weight * (s.is_verified ? 1 : 0),
      0,
    );
    return Math.min(1.0, raw);
  }

  // ── Confidence ─────────────────────────────────────────────────────────────

  /**
   * Step 5 — Confidence index.
   *
   * Formula: CI = 1 - exp(-N_total / 50)
   *
   * If N_total < 5, CI is naturally < 0.10 per formula.
   * The profile is additionally flagged "Provisional Baseline" in that case.
   */
  confidenceIndex(N_total: number): number {
    return 1 - Math.exp(-N_total / 50);
  }

  /**
   * Whether the profile has too few jobs to be reliable (N_total < 5).
   * These profiles are "Provisional Baseline" and CI is forced < 0.10.
   */
  isProvisionalBaseline(N_total: number): boolean {
    return N_total < PROVISIONAL_BASELINE_MAX_JOBS;
  }

  /**
   * Maps a CI value to one of three tier labels.
   *
   * Cut points (Section 12 judgment, derived from CI formula):
   *   LOW            : CI < 0.40   (N_total < ~25)
   *   MEDIUM         : 0.40 ≤ CI < 0.75  (N_total 25–69)
   *   HIGH_CONFIDENCE: CI ≥ 0.75   (N_total ≥ ~70)
   */
  confidenceTier(ci: number): ConfidenceTier {
    if (ci >= CI_THRESHOLD_HIGH) return 'HIGH_CONFIDENCE';
    if (ci >= CI_THRESHOLD_MEDIUM) return 'MEDIUM';
    return 'LOW';
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  private totalJobs(metrics: WorkerMetrics): number {
    // N_total = total jobs across all platforms (spec uses job count, not reviews).
    // Here we use completed jobs as the count, consistent with volume vector usage.
    return metrics.total_jobs_completed;
  }

  private resolveNTarget(domain: string): number {
    return DOMAIN_N_TARGETS[domain] ?? DOMAIN_N_TARGETS['default'];
  }

  private clamp01(value: number): number {
    return Math.max(0, Math.min(1, value));
  }
}

// ── Singleton export for convenience ─────────────────────────────────────────
// NestJS services may inject this as a provider, or tests may instantiate directly.
export const reputationCalculator = new ReputationCalculator();
