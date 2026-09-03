/**
 * reputation-score.entity.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * TypeORM entity mapping to the `reputation_scores` table.
 * Table and columns are owned by Developer 1; this entity is READ-WRITE
 * but must never issue migrations. Any new columns needed here must be
 * proposed via the migration diff in migrations/proposed/.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  Column,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('reputation_scores')
export class ReputationScore {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ type: 'uuid', unique: true })
  worker_id: string;

  /** Composite score [300, 850]. smallint. */
  @Column({ type: 'smallint' })
  composite_score: number;

  /** Sub-vector scores — numeric(5,4) each. */
  @Column({ type: 'numeric', precision: 5, scale: 4 })
  rating_subscore: number;

  @Column({ type: 'numeric', precision: 5, scale: 4 })
  volume_subscore: number;

  @Column({ type: 'numeric', precision: 5, scale: 4 })
  reliability_subscore: number;

  @Column({ type: 'numeric', precision: 5, scale: 4 })
  consistency_subscore: number;

  @Column({ type: 'numeric', precision: 5, scale: 4 })
  skills_subscore: number;

  /** Confidence index CI = 1 - exp(-N/50). numeric(3,2). */
  @Column({ type: 'numeric', precision: 3, scale: 2 })
  confidence_index: number;

  /** LOW | MEDIUM | HIGH_CONFIDENCE */
  @Column({
    type: 'varchar',
    length: 20,
    enum: ['LOW', 'MEDIUM', 'HIGH_CONFIDENCE'],
  })
  confidence_tier: string;

  @Column({ type: 'timestamptz' })
  calculated_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
