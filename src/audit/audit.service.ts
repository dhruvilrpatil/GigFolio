/**
 * audit.service.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Append-only application audit event emitter.
 *
 * Security invariants enforced here:
 *   - Raw IP addresses are NEVER written. Callers must pass ip_address_hash
 *     (SHA-256 hex). The service validates this expectation.
 *   - The `actor_id` may be null for anonymous public-token verifier access.
 *   - Inserts are fire-and-forget with a catch — audit failure does NOT
 *     roll back the business transaction (audit is observability, not
 *     the authoritative record).
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AccessAuditLog } from './entities/access-audit-log.entity';
import { AuditEventDto } from './dto/audit-event.dto';

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(
    @InjectRepository(AccessAuditLog)
    private readonly auditRepo: Repository<AccessAuditLog>,
  ) {}

  /**
   * Emits an immutable audit event.
   *
   * @param event - Audit event data. ip_address_hash must be SHA-256 hex or null.
   *                NEVER pass a raw IP address.
   */
  async emit(event: AuditEventDto): Promise<void> {
    // Validate that ip_address_hash looks like a SHA-256 hex string if provided
    if (
      event.ip_address_hash !== null &&
      !/^[a-f0-9]{64}$/.test(event.ip_address_hash)
    ) {
      this.logger.error(
        'AuditService.emit called with a non-SHA-256 ip_address_hash. ' +
          'Raw IPs must never be logged. Discarding the field.',
        { action: event.action, actor_id: event.actor_id },
      );
      event = { ...event, ip_address_hash: null };
    }

    try {
      const log = this.auditRepo.create({
        actor_id: event.actor_id,
        actor_role: event.actor_role,
        action: event.action,
        target_worker_id: event.target_worker_id,
        accessed_scopes: event.accessed_scopes,
        ip_address_hash: event.ip_address_hash,
        user_agent: event.user_agent,
        correlation_id: event.correlation_id,
      });
      await this.auditRepo.save(log);
    } catch (err: unknown) {
      // Audit failure is non-fatal — log the error but don't propagate.
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.error(`Failed to persist audit event: ${msg}`, {
        action: event.action,
        target_worker_id: event.target_worker_id,
        correlation_id: event.correlation_id,
      });
    }
  }

  /**
   * Helper: hash a raw IP address to a safe audit-log value.
   * Use this in controllers before calling emit().
   */
  static hashIp(rawIp: string | undefined | null): string | null {
    if (!rawIp) return null;
    const { createHash } = require('crypto') as typeof import('crypto');
    return createHash('sha256').update(rawIp, 'utf8').digest('hex');
  }
}
