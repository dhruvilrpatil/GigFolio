/**
 * org-api-key.guard.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Organization API key authentication guard for the Enterprise Verification
 * endpoint (`POST /api/v1/organizations/verify-worker`).
 *
 * Auth flow:
 *   1. Read `X-Organization-Key` header.
 *   2. SHA-256 hash it and look up in the organizations table
 *      (Developer 1 owns the `organizations` table; we query it via the shared DB).
 *   3. Validate: key is active, not expired, has `org:verification:consume` scope.
 *   4. Attach org context to `request.org` for downstream handlers.
 *
 * Returns 401 for any failure — never leak whether the key exists.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Request } from 'express';
import { sha256Hex } from '../utils/hash.util';
import { OrganizationKey } from '../../verification/entities/organization-key.entity';

export interface OrganizationContext {
  id: string;
  name: string;
  permitted_scopes: string[];
}

@Injectable()
export class OrgApiKeyGuard implements CanActivate {
  constructor(
    @InjectRepository(OrganizationKey)
    private readonly orgKeyRepo: Repository<OrganizationKey>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const rawKey = request.headers['x-organization-key'];

    if (!rawKey || typeof rawKey !== 'string') {
      throw new UnauthorizedException('Missing X-Organization-Key header');
    }

    const keyHash = sha256Hex(rawKey);

    const orgKey = await this.orgKeyRepo.findOne({
      where: { key_hash: keyHash, is_active: true },
      relations: ['organization'],
    });

    if (!orgKey) {
      throw new UnauthorizedException('Invalid or inactive organization API key');
    }

    if (orgKey.expires_at && orgKey.expires_at < new Date()) {
      throw new UnauthorizedException('Organization API key has expired');
    }

    if (!orgKey.permitted_scopes.includes('org:verification:consume')) {
      throw new UnauthorizedException(
        'Organization API key lacks required scope: org:verification:consume',
      );
    }

    request['org'] = {
      id: orgKey.organization.id,
      name: orgKey.organization.name,
      permitted_scopes: orgKey.permitted_scopes,
    } satisfies OrganizationContext;

    return true;
  }
}
