/**
 * share-link.entity.ts
 * TypeORM entity for share_links table (owned by Developer 1).
 *
 * CRITICAL SECURITY PROPERTY:
 *   token_hash stores ONLY the SHA-256 of the raw token.
 *   The raw token is NEVER persisted here or anywhere else.
 *   It is returned to the client exactly once at creation time.
 */

import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
  JoinColumn,
} from 'typeorm';
import { ConsentRecord } from './consent-record.entity';

@Entity('share_links')
export class ShareLink {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ type: 'uuid' })
  worker_id: string;

  /**
   * SHA-256(raw_token). Unique index enforces one link per token.
   * NEVER store the raw token.
   */
  @Index({ unique: true })
  @Column({ type: 'char', length: 64 })
  token_hash: string;

  @Column({ type: 'text', array: true, default: '{}' })
  permitted_scopes: string[];

  /**
   * Argon2id hash of the optional passcode.
   * Null if no passcode is set for this link.
   */
  @Column({ type: 'text', nullable: true })
  passcode_hash: string | null;

  @Column({ type: 'integer', nullable: true })
  max_uses: number | null;

  @Column({ type: 'integer', default: 0 })
  current_uses: number;

  @Column({ type: 'timestamptz' })
  expires_at: Date;

  @Column({ type: 'timestamptz', nullable: true })
  revoked_at: Date | null;

  @Column({ type: 'uuid', nullable: true })
  consent_record_id: string | null;

  @ManyToOne(() => ConsentRecord, { nullable: true })
  @JoinColumn({ name: 'consent_record_id' })
  consent_record: ConsentRecord | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
