/**
 * reputation.service.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Orchestrates reputation computation:
 *   1. Loads normalized worker metrics from Developer 2's ingestion tables.
 *   2. Calls ReputationCalculator (pure math, no side effects).
 *   3. Persists results via ReputationRepository.
 *   4. Emits audit events.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { ReputationCalculator } from './reputation-calculator';
import { ReputationRepository } from './reputation.repository';
import { AuditService } from '../audit/audit.service';
import { WorkerMetrics } from './interfaces/worker-metrics.interface';
import { ReputationBreakdown } from './interfaces/reputation-result.interface';

@Injectable()
export class ReputationService {
  private readonly logger = new Logger(ReputationService.name);
  private readonly calculator = new ReputationCalculator();

  constructor(
    private readonly reputationRepo: ReputationRepository,
    private readonly auditService: AuditService,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  /**
   * Recomputes and persists the reputation score for a worker.
   * Called by the BullMQ worker on RECOMPUTE_SCORE_EVENT.
   */
  async recomputeAndPersist(workerId: string): Promise<ReputationBreakdown> {
    this.logger.log(`Recomputing reputation for worker ${workerId}`);

    const metrics = await this.loadWorkerMetrics(workerId);
    const result = this.calculator.compute(metrics);

    await this.reputationRepo.upsertScore(workerId, result);

    // Emit audit event for reputation recalculation (Section 7)
    await this.auditService.emit({
      actor_id: null, // system-triggered
      actor_role: 'system',
      action: 'REPUTATION_RECALCULATED',
      target_worker_id: workerId,
      accessed_scopes: ['reputation:composite_score'],
      ip_address_hash: null,
      user_agent: 'BullMQ-Worker/ReputationRecalculate',
      correlation_id: crypto.randomUUID(),
    });

    this.logger.log(
      `Reputation recalculated for worker ${workerId}: score=${result.composite_score}`,
    );
    return result;
  }

  /**
   * Returns the current reputation breakdown for a worker.
   * Used by GET /api/v1/reputation/breakdown.
   */
  async getBreakdown(workerId: string): Promise<ReputationBreakdown> {
    const score = await this.reputationRepo.findByWorkerId(workerId);
    if (!score) {
      throw new NotFoundException(
        `Reputation score not yet calculated for worker ${workerId}. ` +
          'Trigger a recompute via ingestion or wait for the next scheduled run.',
      );
    }

    return {
      composite_score: Number(score.composite_score),
      rating_subscore: Number(score.rating_subscore),
      volume_subscore: Number(score.volume_subscore),
      reliability_subscore: Number(score.reliability_subscore),
      consistency_subscore: Number(score.consistency_subscore),
      skills_subscore: Number(score.skills_subscore),
      confidence_index: Number(score.confidence_index),
      confidence_tier: score.confidence_tier as ReputationBreakdown['confidence_tier'],
      calculated_at: score.calculated_at,
      // Summaries: load live from metrics for accuracy, or denormalize from score table.
      // For now we compute from stored subscores as an approximation.
      total_verified_jobs: 0,           // populated on full recompute; stale from DB
      aggregate_completion_rate: 0,     // populated on full recompute; stale from DB
      active_platforms_count: 0,        // populated on full recompute; stale from DB
    };
  }

  // ── Private — Developer 2's Data Loading ──────────────────────────────────

  /**
   * Loads normalized worker metrics from the database tables populated by
   * Developer 2's ingestion pipeline.
   *
   * Integration note: Replace raw SQL queries here with Developer 2's
   * typed repository/service calls once the ingestion module is integrated.
   * The WorkerMetrics shape is the integration contract.
   */
  private async loadWorkerMetrics(workerId: string): Promise<WorkerMetrics> {
    // ── Platform ratings ──────────────────────────────────────────────────────
    const platformRows: Array<{
      platform_id: string;
      normalized_mean_rating: string;
      verified_review_count: string;
    }> = await this.dataSource.query(
      `
      SELECT
        platform_id,
        AVG(normalized_rating) AS normalized_mean_rating,
        COUNT(*)               AS verified_review_count
      FROM ratings
      WHERE worker_id = $1
        AND is_verified = true
      GROUP BY platform_id
      `,
      [workerId],
    );

    // ── Job completion counts ─────────────────────────────────────────────────
    const completionRow: {
      total_accepted: string;
      total_completed: string;
      domain: string;
    } | null = await this.dataSource
      .query(
        `
        SELECT
          COUNT(*) FILTER (WHERE status IN ('accepted','completed','cancelled')) AS total_accepted,
          COUNT(*) FILTER (WHERE status = 'completed')                           AS total_completed,
          COALESCE(w.domain, 'default')                                          AS domain
        FROM job_records jr
        JOIN workers w ON w.id = jr.worker_id
        WHERE jr.worker_id = $1
        `,
        [workerId],
      )
      .then((rows: any[]) => rows[0] ?? null);

    // ── 52-week activity ──────────────────────────────────────────────────────
    const weekRows: Array<{ week_number: string }> = await this.dataSource.query(
      `
      SELECT DISTINCT
        EXTRACT(WEEK FROM activity_date)::int AS week_number
      FROM platform_activity
      WHERE worker_id = $1
        AND activity_date >= NOW() - INTERVAL '52 weeks'
      `,
      [workerId],
    );
    const activeWeeks = new Set(weekRows.map((r) => Number(r.week_number)));

    // ── Verified skills ───────────────────────────────────────────────────────
    const skillRows: Array<{
      skill_id: string;
      weight: string;
      is_verified: boolean;
    }> = await this.dataSource.query(
      `
      SELECT sc.skill_id, sc.weight, sc.is_verified
      FROM skill_credentials sc
      WHERE sc.worker_id = $1
      `,
      [workerId],
    );

    return {
      worker_id: workerId,
      platforms: platformRows.map((r) => ({
        platform_id: r.platform_id,
        normalized_mean_rating: Number(r.normalized_mean_rating),
        verified_review_count: Number(r.verified_review_count),
      })),
      total_jobs_accepted: Number(completionRow?.total_accepted ?? 0),
      total_jobs_completed: Number(completionRow?.total_completed ?? 0),
      weekly_activity: Array.from({ length: 52 }, (_, i) => ({
        week: i + 1,
        active: activeWeeks.has(i + 1),
      })),
      skills: skillRows.map((r) => ({
        skill_id: r.skill_id,
        weight: Number(r.weight),
        is_verified: r.is_verified,
      })),
      domain: completionRow?.domain ?? 'default',
    };
  }
}
