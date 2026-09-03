/**
 * public-profile.dto.ts
 * DTOs for the public worker profile lookup and rotation endpoints.
 */

import { ApiProperty } from '@nestjs/swagger';

/** Response for GET /api/v1/public/workers/{worker_public_id} */
export class PublicWorkerProfileDto {
  @ApiProperty({
    description:
      'The stable public handle for this worker. ' +
      'NOT the internal worker UUID — this is safe to share and display.',
    example: '7f3a2b1c-4e5d-6f7a-8b9c-0d1e2f3a4b5c',
  })
  worker_public_id: string;

  @ApiProperty({
    description:
      "Worker-controlled display name. Null if worker has disabled this field.",
    example: 'Jane W.',
    nullable: true,
  })
  display_name: string | null;

  @ApiProperty({
    description: 'Whether the worker\'s identity has been verified by GigFolio.',
    example: true,
    nullable: true,
  })
  is_identity_verified: boolean | null;

  @ApiProperty({
    description:
      'Whether a reputation score has been calculated for this worker. ' +
      'Does NOT reveal the score itself — use the verify-worker endpoint with a share token.',
    example: true,
  })
  has_reputation_score: boolean;

  @ApiProperty({
    description: 'Verification badge earned by this worker.',
    example: 'PLATFORM_VERIFIED',
    enum: ['VERIFIED', 'UNVERIFIED', 'PLATFORM_VERIFIED'],
    nullable: true,
  })
  verification_badge: string | null;

  @ApiProperty({
    description:
      'Hint to the requester: to access actual data (reputation, earnings, identity), ' +
      'obtain a share token from this worker and call POST /api/v1/organizations/verify-worker.',
    example: 'POST /api/v1/organizations/verify-worker with a share_token from this worker.',
  })
  data_access_hint: string;
}

/** Response for POST /api/v1/workers/me/rotate-public-id */
export class RotatePublicIdResponseDto {
  @ApiProperty({
    description: 'The new public ID. The old one is immediately invalidated.',
    example: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  })
  new_worker_public_id: string;

  @ApiProperty({ example: '2026-09-03T19:00:00Z' })
  rotated_at: string;

  @ApiProperty({
    description: 'The old public ID, now permanently invalidated.',
    example: '7f3a2b1c-4e5d-6f7a-8b9c-0d1e2f3a4b5c',
  })
  previous_public_id: string;
}
