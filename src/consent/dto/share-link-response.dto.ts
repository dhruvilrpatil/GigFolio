/**
 * share-link-response.dto.ts
 * Response DTOs for consent/share-link endpoints.
 */

import { ApiProperty } from '@nestjs/swagger';

/** Response for POST /api/v1/consent/share-links (Section 4.4 exact shape). */
export class ShareLinkResponseDto {
  @ApiProperty({
    description:
      'Opaque raw share token — shown EXACTLY ONCE. Never stored in plaintext. ' +
      'Include in share_url or QR for verifier access.',
    example: 'aB3xZ9_qR2mN5kL7eW4tY8sD1jF6hC0',
  })
  share_token: string;

  @ApiProperty({
    description: 'Full share URL the verifier uses to access the profile.',
    example: 'https://gigfolio.io/verify/aB3xZ9_qR2mN5kL7eW4tY8sD1jF6hC0',
  })
  share_url: string;

  @ApiProperty({
    description: 'URL of the QR code SVG asset encoding the share_url.',
    example: 'https://gigfolio.io/qr/aB3xZ9_qR2mN5kL7eW4tY8sD1jF6hC0.svg',
  })
  qr_code_svg_url: string;

  @ApiProperty({
    description: 'Scopes the verifier is permitted to access.',
    example: ['identity:name_only', 'earnings:monthly_aggregate', 'reputation:composite_score'],
    type: [String],
  })
  permitted_scopes: string[];

  @ApiProperty({
    description: 'ISO-8601 UTC expiration timestamp.',
    example: '2026-09-06T12:00:00Z',
  })
  expires_at: string;
}

/** Response for DELETE /api/v1/consent/share-links/{id} */
export class RevokeLinkResponseDto {
  @ApiProperty({ example: 'Share link revoked successfully.' })
  message: string;

  @ApiProperty({ example: '2026-09-03T18:00:00Z' })
  revoked_at: string;
}
