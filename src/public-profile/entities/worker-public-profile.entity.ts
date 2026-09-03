/**
 * worker-public-profile.entity.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * TypeORM entity for worker_public_profiles table (proposed in migrations/proposed/).
 * Paired with the `public_id` column added to the workers table.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * The lightweight public-facing projection of a worker profile.
 * Returned by GET /api/v1/public/workers/{worker_public_id}.
 * Contains only worker-controlled discoverable fields — NEVER sensitive data.
 */
export interface PublicWorkerView {
  /** The stable, externally-shared public ID. NOT the internal worker UUID. */
  worker_public_id: string;
  /** Worker-controlled display name (only if show_display_name = true). */
  display_name: string | null;
  /** Whether identity has been verified by GigFolio. */
  is_identity_verified: boolean | null;
  /** Whether a reputation score has been calculated (not the score itself). */
  has_reputation_score: boolean;
  /** Verification badge label. */
  verification_badge: 'VERIFIED' | 'UNVERIFIED' | 'PLATFORM_VERIFIED' | null;
  /** ISO-8601 timestamp of when the profile was last updated. */
  profile_updated_at: string | null;
}

@Entity('worker_public_profiles')
export class WorkerPublicProfile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index({ unique: true })
  @Column({ type: 'uuid' })
  worker_id: string;

  /** Worker controls which fields appear in the public discovery response. */
  @Column({ type: 'boolean', default: true })
  show_display_name: boolean;

  @Column({ type: 'boolean', default: true })
  show_verification_badge: boolean;

  @Column({ type: 'boolean', default: true })
  show_has_reputation: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
