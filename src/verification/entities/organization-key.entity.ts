/**
 * organization-key.entity.ts
 * TypeORM entity for organization API keys (consumed by OrgApiKeyGuard).
 * Table is jointly managed by Developer 1 (schema) and used by Developer 3.
 */

import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
  JoinColumn,
} from 'typeorm';

@Entity('organizations')
export class Organization {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 200 })
  name: string;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;
}

@Entity('organization_api_keys')
export class OrganizationKey {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index({ unique: true })
  @Column({ type: 'char', length: 64 })
  key_hash: string; // SHA-256 of the raw API key

  @Column({ type: 'text', array: true, default: '{}' })
  permitted_scopes: string[];

  @Column({ type: 'boolean', default: true })
  is_active: boolean;

  @Column({ type: 'timestamptz', nullable: true })
  expires_at: Date | null;

  @Column({ type: 'uuid' })
  organization_id: string;

  @ManyToOne(() => Organization)
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;
}
