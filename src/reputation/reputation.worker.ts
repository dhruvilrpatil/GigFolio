/**
 * reputation.worker.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * BullMQ processor for the `RECOMPUTE_SCORE_EVENT` event published by
 * Developer 2's ingestion pipeline after data normalization completes.
 *
 * Queue name: 'reputation' (must match the producer queue name used by Dev 2)
 * Event name: 'RECOMPUTE_SCORE_EVENT' (DO NOT rename without coordination)
 *
 * Processing guarantees:
 *   - At-least-once delivery (BullMQ default)
 *   - Idempotent: upsert is safe to run multiple times for the same worker
 *   - Failed jobs are retried with exponential backoff (configured in module)
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { ReputationService } from './reputation.service';

/** Payload shape published by Developer 2. */
export interface RecomputeScoreEventPayload {
  worker_id: string;
  /** Optional: reason for recompute (e.g., 'ingestion_complete', 'manual_trigger') */
  trigger?: string;
}

/** Queue name — must stay in sync with Developer 2's producer configuration. */
export const REPUTATION_QUEUE = 'reputation';

/** Event name — DO NOT change without Developer 2 coordination (Section 3.5). */
export const RECOMPUTE_SCORE_EVENT = 'RECOMPUTE_SCORE_EVENT';

@Processor(REPUTATION_QUEUE)
export class ReputationWorker extends WorkerHost {
  private readonly logger = new Logger(ReputationWorker.name);

  constructor(private readonly reputationService: ReputationService) {
    super();
  }

  async process(job: Job<RecomputeScoreEventPayload>): Promise<void> {
    if (job.name !== RECOMPUTE_SCORE_EVENT) {
      this.logger.warn(
        `Unknown job name received on reputation queue: ${job.name}. Skipping.`,
      );
      return;
    }

    const { worker_id, trigger } = job.data;

    if (!worker_id) {
      this.logger.error(`Job ${job.id} missing worker_id payload. Discarding.`);
      throw new Error('Missing worker_id in RECOMPUTE_SCORE_EVENT payload');
    }

    this.logger.log(
      `[Job ${job.id}] Processing RECOMPUTE_SCORE_EVENT for worker=${worker_id}` +
        (trigger ? ` trigger=${trigger}` : ''),
    );

    try {
      const result = await this.reputationService.recomputeAndPersist(worker_id);
      this.logger.log(
        `[Job ${job.id}] Reputation computed: worker=${worker_id} ` +
          `score=${result.composite_score} tier=${result.confidence_tier}`,
      );
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.error(
        `[Job ${job.id}] Failed to compute reputation for worker=${worker_id}: ${message}`,
      );
      // Re-throw so BullMQ marks the job as failed and applies retry policy.
      throw err;
    }
  }
}
