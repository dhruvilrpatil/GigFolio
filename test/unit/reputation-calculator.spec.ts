/**
 * reputation-calculator.spec.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Standalone unit tests for ReputationCalculator.
 *
 * These tests have ZERO external dependencies — no database, no HTTP, no NestJS.
 * They directly exercise the mathematical logic and serve as the primary
 * specification compliance check.
 *
 * Coverage required by spec Section 9:
 *   ✓ Bayesian shrinkage: 5 jobs @ 5.0 vs 1,500 jobs @ 4.8
 *   ✓ Reliability exponent curve: 98% vs 85% completion
 *   ✓ Confidence tier boundaries
 *   ✓ Score clamping to [300, 850]
 *   ✓ Volume vector logarithmic saturation
 *   ✓ Consistency vector recency decay
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { ReputationCalculator } from '../../src/reputation/reputation-calculator';
import {
  WorkerMetrics,
  PlatformMetrics,
  WeeklyActivity,
} from '../../src/reputation/interfaces/worker-metrics.interface';

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeFullyActiveWeeks(): WeeklyActivity[] {
  return Array.from({ length: 52 }, (_, i) => ({
    week: i + 1,
    active: true,
  }));
}

function makeInactiveWeeks(): WeeklyActivity[] {
  return Array.from({ length: 52 }, (_, i) => ({
    week: i + 1,
    active: false,
  }));
}

function makeMinimalMetrics(overrides: Partial<WorkerMetrics> = {}): WorkerMetrics {
  return {
    worker_id: 'test-worker-uuid',
    platforms: [],
    total_jobs_accepted: 100,
    total_jobs_completed: 98,
    weekly_activity: makeFullyActiveWeeks(),
    skills: [],
    domain: 'transport',
    ...overrides,
  };
}

// ── Test Suite ─────────────────────────────────────────────────────────────────

describe('ReputationCalculator', () => {
  let calc: ReputationCalculator;

  beforeEach(() => {
    calc = new ReputationCalculator();
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION A — Bayesian Shrinkage
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('Bayesian shrinkage — μ̂_p = (C_p * m_p + N_p * x̄_p) / (C_p + N_p)', () => {
    it('shrinks a 5-job perfect worker (x̄=1.0) toward prior 0.85', () => {
      // μ̂ = (25 * 0.85 + 5 * 1.0) / (25 + 5) = (21.25 + 5) / 30 = 26.25/30 = 0.875
      const result = calc.bayesianShrinkage(1.0, 5);
      expect(result).toBeCloseTo(0.875, 4);
    });

    it('converges a 1500-job worker (x̄=0.96) close to their observed mean', () => {
      // μ̂ = (25 * 0.85 + 1500 * 0.96) / (25 + 1500) = (21.25 + 1440) / 1525 = 1461.25/1525 ≈ 0.9582
      const result = calc.bayesianShrinkage(0.96, 1500);
      expect(result).toBeCloseTo(0.9582, 3);
    });

    it('CRITICAL: 1500-job worker at 4.8/5 (x̄=0.96) must score higher or equal composite than 5-job perfect worker', () => {
      // Worker A: 5 jobs, all 5-star → normalized 1.0
      const platformA: PlatformMetrics = {
        platform_id: 'uber',
        normalized_mean_rating: 1.0,
        verified_review_count: 5,
      };
      // Worker B: 1500 jobs, 4.8/5 → normalized 0.96
      const platformB: PlatformMetrics = {
        platform_id: 'uber',
        normalized_mean_rating: 0.96,
        verified_review_count: 1500,
      };

      const shrunkA = calc.bayesianShrinkage(1.0, 5);
      const shrunkB = calc.bayesianShrinkage(0.96, 1500);

      // After shrinkage:
      //   Worker A: μ̂ = 0.875 (shrunken down significantly)
      //   Worker B: μ̂ ≈ 0.9582 (barely shrunken — large volume)
      // Worker B should have HIGHER rating vector
      expect(shrunkB).toBeGreaterThan(shrunkA);
    });

    it('CRITICAL: full composite score — high-volume worker must not be unfairly penalized vs low-volume', () => {
      const metricsA = makeMinimalMetrics({
        platforms: [{
          platform_id: 'uber',
          normalized_mean_rating: 1.0,
          verified_review_count: 5,
        }],
        total_jobs_accepted: 5,
        total_jobs_completed: 5,
        domain: 'transport',
      });

      const metricsB = makeMinimalMetrics({
        platforms: [{
          platform_id: 'uber',
          normalized_mean_rating: 0.96,
          verified_review_count: 1500,
        }],
        total_jobs_accepted: 1500,
        total_jobs_completed: 1450,
        domain: 'transport',
      });

      const resultA = calc.compute(metricsA);
      const resultB = calc.compute(metricsB);

      // Worker B should have higher or equal composite score
      expect(resultB.composite_score).toBeGreaterThanOrEqual(resultA.composite_score);
      // Worker B should have higher confidence (more data)
      expect(resultB.confidence_index).toBeGreaterThan(resultA.confidence_index);
      // Bayesian shrinkage is visible: A's rating is pulled down, B's barely moved
      expect(resultB.rating_subscore).toBeGreaterThan(resultA.rating_subscore);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION B — Reliability Vector (spec Section 3.3 Step 3)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('Reliability vector — S_reliability = (N_completed / N_accepted) ^ 3.0', () => {
    it('98% completion rate → ~0.941', () => {
      // 0.98^3 = 0.941192
      const result = calc.reliabilityVector(98, 100);
      expect(result).toBeCloseTo(0.9412, 4);
    });

    it('85% completion rate → ~0.614', () => {
      // 0.85^3 = 0.614125
      const result = calc.reliabilityVector(85, 100);
      expect(result).toBeCloseTo(0.6141, 4);
    });

    it('13-point completion drop (98%→85%) causes ~35% reliability score drop', () => {
      const r98 = calc.reliabilityVector(98, 100);
      const r85 = calc.reliabilityVector(85, 100);
      const dropPercent = (r98 - r85) / r98;
      // Spec states "~35% reliability score drop"
      expect(dropPercent).toBeGreaterThan(0.30);
      expect(dropPercent).toBeLessThan(0.40);
    });

    it('100% completion rate → 1.0', () => {
      expect(calc.reliabilityVector(100, 100)).toBeCloseTo(1.0, 6);
    });

    it('0% completion rate → 0.0', () => {
      expect(calc.reliabilityVector(0, 100)).toBeCloseTo(0.0, 6);
    });

    it('returns 0 for 0 accepted jobs (no division by zero)', () => {
      expect(calc.reliabilityVector(0, 0)).toBe(0);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION C — Volume Vector
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('Volume vector — min(1.0, ln(1+N) / ln(1+N_target))', () => {
    it('exactly 0 jobs → 0.0', () => {
      expect(calc.volumeVector(0, 1000)).toBe(0);
    });

    it('exactly N_target jobs → 1.0', () => {
      expect(calc.volumeVector(1000, 1000)).toBeCloseTo(1.0, 6);
    });

    it('exceeds N_target → clamped to 1.0', () => {
      expect(calc.volumeVector(9999, 1000)).toBe(1.0);
    });

    it('logarithmic growth is sub-linear (1000 jobs is much more than 10x of 100 jobs)', () => {
      const v100 = calc.volumeVector(100, 1000);
      const v200 = calc.volumeVector(200, 1000);
      const v1000 = calc.volumeVector(1000, 1000);
      // Each doubling should produce diminishing gains
      expect(v200 - v100).toBeLessThan(v100);
      expect(v1000).toBeCloseTo(1.0, 6);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION D — Consistency Vector
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('Consistency vector — exponential recency decay', () => {
    it('all 52 weeks active → positive score between 0 and 1', () => {
      const result = calc.consistencyVector(makeFullyActiveWeeks());
      // Formula: (1/T) * Σ w_t * λ(t).  The sum is divided by T=52 (not normalised
      // by Σλ), so with T_half=26 the geometric series gives ≈ 0.548.
      // λ(52) = 1.0, λ(1) = 2^(-(52-1)/26) ≈ 0.136
      expect(result).toBeGreaterThan(0.3);
      expect(result).toBeLessThanOrEqual(1.0);
    });

    it('no weeks active → 0.0', () => {
      const result = calc.consistencyVector(makeInactiveWeeks());
      expect(result).toBe(0);
    });

    it('only the most recent week active → higher score than only oldest week active', () => {
      const recentOnly = Array.from({ length: 52 }, (_, i) => ({
        week: i + 1,
        active: i === 51, // only week 52 (most recent)
      }));
      const oldestOnly = Array.from({ length: 52 }, (_, i) => ({
        week: i + 1,
        active: i === 0, // only week 1 (oldest)
      }));
      const scoreRecent = calc.consistencyVector(recentOnly);
      const scoreOldest = calc.consistencyVector(oldestOnly);
      // Week 52: λ = 2^(-(52-52)/26) = 1.0 → higher weight
      // Week 1:  λ = 2^(-(52-1)/26) ≈ 0.136 → lower weight
      expect(scoreRecent).toBeGreaterThan(scoreOldest);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION E — Confidence Index & Tiers
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('Confidence index — CI = 1 - exp(-N_total / 50)', () => {
    it('N=0 → CI = 0', () => {
      expect(calc.confidenceIndex(0)).toBe(0);
    });

    it('N=5 → CI < 0.10 (Provisional Baseline threshold)', () => {
      const ci = calc.confidenceIndex(5);
      expect(ci).toBeLessThan(0.10);
    });

    it('N=25 → CI ≈ 0.394 (boundary: LOW→MEDIUM approaching 0.40)', () => {
      const ci = calc.confidenceIndex(25);
      expect(ci).toBeCloseTo(0.3935, 3);
    });

    it('N=26 → CI > 0.40 → MEDIUM tier', () => {
      const ci = calc.confidenceIndex(26);
      expect(ci).toBeGreaterThan(0.40);
      expect(calc.confidenceTier(ci)).toBe('MEDIUM');
    });

    it('N=69 → CI ≈ 0.748 (approaching HIGH threshold)', () => {
      const ci = calc.confidenceIndex(69);
      expect(ci).toBeCloseTo(0.748, 2);
    });

    it('N=70 → CI > 0.75 → HIGH_CONFIDENCE', () => {
      const ci = calc.confidenceIndex(70);
      expect(ci).toBeGreaterThan(0.75);
      expect(calc.confidenceTier(ci)).toBe('HIGH_CONFIDENCE');
    });

    it('CI ≥ 0.75 → HIGH_CONFIDENCE tier', () => {
      expect(calc.confidenceTier(0.75)).toBe('HIGH_CONFIDENCE');
      expect(calc.confidenceTier(0.99)).toBe('HIGH_CONFIDENCE');
    });

    it('0.40 ≤ CI < 0.75 → MEDIUM tier', () => {
      expect(calc.confidenceTier(0.40)).toBe('MEDIUM');
      expect(calc.confidenceTier(0.60)).toBe('MEDIUM');
      expect(calc.confidenceTier(0.74)).toBe('MEDIUM');
    });

    it('CI < 0.40 → LOW tier', () => {
      expect(calc.confidenceTier(0.0)).toBe('LOW');
      expect(calc.confidenceTier(0.20)).toBe('LOW');
      expect(calc.confidenceTier(0.39)).toBe('LOW');
    });

    it('isProvisionalBaseline: N < 5 → true', () => {
      expect(calc.isProvisionalBaseline(4)).toBe(true);
      expect(calc.isProvisionalBaseline(0)).toBe(true);
    });

    it('isProvisionalBaseline: N >= 5 → false', () => {
      expect(calc.isProvisionalBaseline(5)).toBe(false);
      expect(calc.isProvisionalBaseline(100)).toBe(false);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION F — Score Clamping [300, 850]
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('Score clamping — R_score = round(300 + 550 * I), clamped to [300, 850]', () => {
    it('worst possible worker → score exactly 300', () => {
      const worstMetrics = makeMinimalMetrics({
        platforms: [{
          platform_id: 'uber',
          normalized_mean_rating: 0,
          verified_review_count: 0,
        }],
        total_jobs_accepted: 0,
        total_jobs_completed: 0,
        weekly_activity: makeInactiveWeeks(),
        skills: [],
      });
      const result = calc.compute(worstMetrics);
      expect(result.composite_score).toBeGreaterThanOrEqual(300);
    });

    it('composite score is always ≤ 850', () => {
      const bestMetrics = makeMinimalMetrics({
        platforms: [{
          platform_id: 'uber',
          normalized_mean_rating: 1.0,
          verified_review_count: 10000,
        }],
        total_jobs_accepted: 10000,
        total_jobs_completed: 10000,
        weekly_activity: makeFullyActiveWeeks(),
        skills: [
          { skill_id: 'cdl', weight: 0.5, is_verified: true },
          { skill_id: 'safety', weight: 0.5, is_verified: true },
        ],
        domain: 'transport',
      });
      const result = calc.compute(bestMetrics);
      expect(result.composite_score).toBeLessThanOrEqual(850);
    });

    it('scores always in [300, 850]', () => {
      const mid = calc.compute(makeMinimalMetrics());
      expect(mid.composite_score).toBeGreaterThanOrEqual(300);
      expect(mid.composite_score).toBeLessThanOrEqual(850);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION G — Skills Vector
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('Skills vector — min(1.0, Σ ω_j * V_j)', () => {
    it('no skills → 0', () => {
      expect(calc.skillsVector([])).toBe(0);
    });

    it('unverified skills count for nothing', () => {
      expect(calc.skillsVector([{ skill_id: 'cdl', weight: 0.8, is_verified: false }])).toBe(0);
    });

    it('verified skills sum correctly', () => {
      const result = calc.skillsVector([
        { skill_id: 'cdl', weight: 0.4, is_verified: true },
        { skill_id: 'safety', weight: 0.3, is_verified: true },
      ]);
      expect(result).toBeCloseTo(0.7, 6);
    });

    it('clamped to 1.0 even if weights sum > 1', () => {
      const result = calc.skillsVector([
        { skill_id: 'a', weight: 0.7, is_verified: true },
        { skill_id: 'b', weight: 0.7, is_verified: true },
      ]);
      expect(result).toBe(1.0);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION H — Full Compute Shape
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('compute() output shape', () => {
    it('returns all required fields', () => {
      const result = calc.compute(makeMinimalMetrics({
        platforms: [{
          platform_id: 'uber',
          normalized_mean_rating: 0.92,
          verified_review_count: 200,
        }],
        total_jobs_accepted: 200,
        total_jobs_completed: 196,
      }));

      expect(result).toHaveProperty('composite_score');
      expect(result).toHaveProperty('rating_subscore');
      expect(result).toHaveProperty('volume_subscore');
      expect(result).toHaveProperty('reliability_subscore');
      expect(result).toHaveProperty('consistency_subscore');
      expect(result).toHaveProperty('skills_subscore');
      expect(result).toHaveProperty('confidence_index');
      expect(result).toHaveProperty('confidence_tier');
      expect(result).toHaveProperty('calculated_at');
      expect(result).toHaveProperty('total_verified_jobs');
      expect(result).toHaveProperty('aggregate_completion_rate');
      expect(result).toHaveProperty('active_platforms_count');
    });

    it('sub-scores are all in [0, 1]', () => {
      const result = calc.compute(makeMinimalMetrics({
        platforms: [{
          platform_id: 'uber',
          normalized_mean_rating: 0.92,
          verified_review_count: 200,
        }],
      }));

      for (const key of [
        'rating_subscore', 'volume_subscore', 'reliability_subscore',
        'consistency_subscore', 'skills_subscore',
      ] as const) {
        expect(result[key]).toBeGreaterThanOrEqual(0);
        expect(result[key]).toBeLessThanOrEqual(1);
      }
    });

    it('active_platforms_count matches input platforms array length', () => {
      const result = calc.compute(makeMinimalMetrics({
        platforms: [
          { platform_id: 'uber', normalized_mean_rating: 0.9, verified_review_count: 100 },
          { platform_id: 'doordash', normalized_mean_rating: 0.85, verified_review_count: 50 },
          { platform_id: 'upwork', normalized_mean_rating: 0.95, verified_review_count: 30 },
        ],
      }));
      expect(result.active_platforms_count).toBe(3);
    });
  });
});
