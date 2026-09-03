/**
 * public.decorator.ts
 * Marks a route as publicly accessible (bypasses JwtAuthGuard).
 */
import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
