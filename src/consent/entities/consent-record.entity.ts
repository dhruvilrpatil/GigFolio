/**
 * consent-record.entity.ts
 * TypeORM entity for consent_records table (owned by Developer 1).
 */

import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('consent_records')
export class ConsentRecord {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ type: 'uuid' })
  worker_id: string;

  @Index()
  @Column({ type: 'uuid', nullable: true })
  organization_id: string | null;

  @Column({ type: 'varchar', length: 100 })
  purpose_code: string;

  @Column({ type: 'text', array: true, default: '{}' })
  permitted_scopes: string[];

  @Column({
    type: 'varchar',
    length: 20,
    enum: ['ACTIVE', 'REVOKED', 'EXPIRED'],
    default: 'ACTIVE',
  })
  status: 'ACTIVE' | 'REVOKED' | 'EXPIRED';

  @Column({ type: 'timestamptz' })
  valid_from: Date;

  @Column({ type: 'timestamptz' })
  valid_until: Date;

  /**
   * SHA-256 of the immutable consent JSON — integrity anchor.
   * Used to detect tampering with historical consent records.
   */
  @Column({ type: 'char', length: 64 })
  signed_artifact_hash: string;

  @Column({ type: 'timestamptz', nullable: true })
  revoked_at: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
