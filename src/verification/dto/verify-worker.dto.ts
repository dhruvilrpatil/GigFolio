/**
 * verify-worker.dto.ts
 * DTOs for POST /api/v1/organizations/verify-worker.
 */

import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

/** Request body — Section 6.1 exact shape. */
export class VerifyWorkerRequestDto {
  @ApiProperty({
    description: 'Raw share token from QR code or link (NOT the hash).',
    example: 'aB3xZ9_qR2mN5kL7eW4tY8sD1jF6hC0',
  })
  @IsString()
  @IsNotEmpty()
  share_token: string;

  @ApiProperty({
    description: 'Optional passcode if the share link was protected with one.',
    example: 'secure-pin-1234',
    required: false,
  })
  @IsOptional()
  @IsString()
  @MaxLength(256)
  access_passcode?: string;

  @ApiProperty({
    description: 'Cryptographic challenge nonce from the verifier (for key-binding / replay protection).',
    example: 'c8a3f2e1-9b7d-4a2c-8f1e-3d4b5c6a7e8f',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(512)
  verifier_nonce: string;

  @ApiProperty({
    description:
      'Optional: the worker_public_id discovered via GET /api/v1/public/workers/{id}. ' +
      'When provided, the backend validates that the share_token belongs to this public ID, ' +
      'preventing cross-worker token confusion attacks.',
    example: '7f3a2b1c-4e5d-6f7a-8b9c-0d1e2f3a4b5c',
    required: false,
  })
  @IsOptional()
  @IsString()
  @MaxLength(36)
  worker_public_id?: string;
}

/** Worker identity fields in the response — only consented fields present. */
export class VerificationWorkerDto {
  [field: string]: unknown;
}

/** Verified metrics — only consented performance data. */
export class VerifiedMetricsDto {
  [field: string]: unknown;
}

/** Full verification response — Section 6.1 exact shape. */
export class VerifyWorkerResponseDto {
  @ApiProperty({
    description: 'UUID for this verification event (for audit trail and receipt).',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  verification_event_id: string;

  @ApiProperty({
    description: 'Only consented identity fields (e.g., legal_name). No address, phone, SSN, etc.',
    example: { legal_name: 'John Doe' },
  })
  worker: Record<string, unknown>;

  @ApiProperty({
    description: 'Verification tier based on available evidence.',
    example: 'PLATFORM_VERIFIED',
    enum: ['SELF_REPORTED', 'PLATFORM_VERIFIED', 'GOVERNMENT_VERIFIED'],
  })
  verification_tier: string;

  @ApiProperty({
    description: 'Only consented performance metrics.',
    example: { composite_score: 782, confidence_tier: 'HIGH_CONFIDENCE' },
  })
  verified_metrics: Record<string, unknown>;

  @ApiProperty({
    description: 'Compact SD-JWT presentation string containing only consented disclosures, key-bound to verifier_nonce.',
    example: 'eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ3b3JrZXIifQ.SIGNATURE~DISCLOSURE~',
  })
  sd_jwt_presentation: string;
}
