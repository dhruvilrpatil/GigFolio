/**
 * qr.service.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * QR code generation service.
 *
 * Design (Section 5 & 12):
 *   - Generates QR codes encoding the share_url (not raw token data).
 *   - Backend remains authoritative — the mobile app ONLY displays the QR.
 *   - Approach: on-demand SVG generation via the `qrcode` library.
 *   - SVG is stored to Cloudflare R2 (or a local stub path in dev) and a
 *     public URL is returned. The token/sensitive data never appears in the QR.
 *
 * R2 integration:
 *   The actual R2 upload is stubbed behind an upload() method.
 *   Replace it with the @aws-sdk/client-s3 R2 call when credentials are available.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as QRCode from 'qrcode';

@Injectable()
export class QrService {
  private readonly logger = new Logger(QrService.name);
  private readonly appBaseUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.appBaseUrl = this.configService.get<string>(
      'APP_BASE_URL',
      'https://gigfolio.io',
    );
  }

  /**
   * Generates a QR code SVG for the given share URL and returns a public URL
   * where the verifier can retrieve it.
   *
   * The share_url itself is encoded in the QR (not the raw token).
   * The QR URL returned is deterministic from the token (slug-based) so it
   * can be re-requested without regeneration.
   *
   * @param shareUrl - The full share URL to encode in the QR.
   * @param tokenSlug - The raw token (base64url) used as the filename slug.
   *                    Note: only the slug (not the hash) is used for the filename,
   *                    as this is a public reference, not a secret.
   * @returns URL of the generated QR code SVG.
   */
  async generateQrCodeUrl(
    shareUrl: string,
    tokenSlug: string,
  ): Promise<string> {
    const svgContent = await QRCode.toString(shareUrl, {
      type: 'svg',
      errorCorrectionLevel: 'M',
      margin: 4,
      width: 300,
      color: {
        dark: '#1a1a2e',  // GigFolio brand dark
        light: '#ffffff',
      },
    });

    // Upload to R2 (or dev stub)
    const filename = `${tokenSlug}.svg`;
    await this.uploadToR2(filename, svgContent);

    return `${this.appBaseUrl}/qr/${filename}`;
  }

  /**
   * R2 upload stub.
   *
   * Production replacement:
   * ```typescript
   * import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
   * const client = new S3Client({ region: 'auto', endpoint: R2_ENDPOINT });
   * await client.send(new PutObjectCommand({
   *   Bucket: this.configService.get('R2_BUCKET'),
   *   Key: `qr/${filename}`,
   *   Body: svgContent,
   *   ContentType: 'image/svg+xml',
   *   CacheControl: 'public, max-age=86400',
   * }));
   * ```
   */
  private async uploadToR2(filename: string, content: string): Promise<void> {
    // Dev stub: log only. Replace with real R2 upload in production.
    this.logger.debug(`[R2 stub] Would upload QR: qr/${filename} (${content.length} bytes)`);
  }
}
