/**
 * create-share-link.dto.ts
 * Request DTO for POST /api/v1/consent/share-links.
 */

import { ApiProperty } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/** Maximum allowed TTL per spec Section 4.4 — HARD LIMIT, NO EXCEPTIONS. */
export const MAX_TTL_HOURS = 720;

/** Known valid scope patterns — extend as needed (keep snake_case:colon convention). */
export const VALID_SCOPE_PREFIXES = [
  'identity:',
  'earnings:',
  'reputation:',
  'verification:',
  'skills:',
];

export class CreateShareLinkDto {
  @ApiProperty({
    description: 'Scopes the verifier is permitted to access',
    example: ['identity:name_only', 'earnings:monthly_aggregate', 'reputation:composite_score'],
    type: [String],
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @IsString({ each: true })
  permitted_scopes: string[];

  @ApiProperty({
    description: `TTL in hours. Maximum ${MAX_TTL_HOURS} hours. Required.`,
    example: 72,
    minimum: 1,
    maximum: MAX_TTL_HOURS,
  })
  @IsInt()
  @Min(1)
  @Max(MAX_TTL_HOURS)
  ttl_hours: number;

  @ApiProperty({
    description: 'Maximum number of times this link may be used. Null = unlimited.',
    example: 1,
    required: false,
    nullable: true,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  max_uses?: number;

  @ApiProperty({
    description: 'Optional passcode to protect the share link (Argon2id hashed at rest).',
    example: 'secure-pin-1234',
    required: false,
  })
  @IsOptional()
  @IsString()
  @MaxLength(256)
  passcode?: string;
}
