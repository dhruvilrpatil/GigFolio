/**
 * access-audit-log.entity.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * TypeORM entity for access_audit_logs table (owned by Developer 1).
 * This table is APPEND-ONLY: insert only, never update or delete.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity('access_audit_logs')
export class AccessAuditLog {
  /** BIGSERIAL PK owned by Developer 1's schema. */
  @PrimaryGeneratedColumn('increment', { type: 'bigint' })
  id: string;

  @Index()
  @Column({ type: 'uuid', nullable: true })
  actor_id: string | null;

  @Column({ type: 'varchar', length: 20 })
  actor_role: string;

  @Index()
  @Column({ type: 'varchar', length: 60 })
  action: string;

  @Index()
  @Column({ type: 'uuid' })
  target_worker_id: string;

  /** Only consented scopes disclosed in this event. */
  @Column({ type: 'text', array: true, default: '{}' })
  accessed_scopes: string[];

  /** SHA-256 hash of requester IP — NEVER raw IP. */
  @Column({ type: 'char', length: 64, nullable: true })
  ip_address_hash: string | null;

  @Column({ type: 'text', nullable: true })
  user_agent: string | null;

  @Index()
  @Column({ type: 'uuid' })
  correlation_id: string;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;
}
