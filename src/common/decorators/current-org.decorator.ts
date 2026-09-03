/**
 * current-org.decorator.ts
 * Extracts the authenticated organization context (set by OrgApiKeyGuard).
 */
import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { OrganizationContext } from '../guards/org-api-key.guard';

export const CurrentOrg = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): OrganizationContext => {
    const request = ctx.switchToHttp().getRequest();
    return request.org as OrganizationContext;
  },
);
