/**
 * reputation.repository.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Database persistence layer for reputation scores.
 * Wraps TypeORM with an upsert that matches the spec requirement to write
 * to reputation_scores on every recomputation.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ReputationScore } from './entities/reputation-score.entity';
import { ReputationResult } from './interfaces/reputation-result.interface';

@Injectable()
export class ReputationRepository {
  constructor(
    @InjectRepository(ReputationScore)
    private readonly repo: Repository<ReputationScore>,
  ) {}

  /**
   * Upsert a reputation result for a worker.
   * Uses PostgreSQL ON CONFLICT DO UPDATE to ensure idempotency.
   * Always overwrites — the latest computed result wins.
   */
  async upsertScore(
    workerId: string,
    result: ReputationResult,
  ): Promise<ReputationScore> {
    await this.repo
      .createQueryBuilder()
      .insert()
      .into(ReputationScore)
      .values({
        worker_id: workerId,
        composite_score: result.composite_score,
        rating_subscore: result.rating_subscore,
        volume_subscore: result.volume_subscore,
        reliability_subscore: result.reliability_subscore,
        consistency_subscore: result.consistency_subscore,
        skills_subscore: result.skills_subscore,
        confidence_index: result.confidence_index,
        confidence_tier: result.confidence_tier,
        calculated_at: result.calculated_at,
      })
      .orUpdate(
        [
          'composite_score', 'rating_subscore', 'volume_subscore',
          'reliability_subscore', 'consistency_subscore', 'skills_subscore',
          'confidence_index', 'confidence_tier', 'calculated_at', 'updated_at',
        ],
        ['worker_id'],
      )
      .execute();

    return this.repo.findOneOrFail({ where: { worker_id: workerId } });
  }

  /**
   * Fetch the latest reputation score for a worker.
   * Returns null if not yet calculated.
   */
  async findByWorkerId(workerId: string): Promise<ReputationScore | null> {
    return this.repo.findOne({ where: { worker_id: workerId } });
  }
}
