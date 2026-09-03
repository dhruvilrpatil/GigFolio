/**
 * projection.service.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Scope-driven data projection — the enforcement layer for consent boundaries.
 *
 * CRITICAL DESIGN INVARIANT (spec Section 6.2 step 3):
 *   "Prefer scope-driven query projection over post-hoc stripping."
 *   "No field the worker didn't authorize should ever be constructed
 *    into the response object, not just filtered after the fact."
 *
 * Implementation:
 *   - The scope → field mapping is declared up front.
 *   - `buildWorkerResponse()` constructs the response object by ONLY
 *     picking fields that are in the allowed set for the given scopes.
 *   - Sensitive fields (address, phone, SSN/TIN, OAuth tokens, documents)
 *     are NEVER present in the output for any scope — they must be
 *     explicitly present in SCOPE_FIELD_MAP to ever appear.
 *
 * Unit test in test/unit/projection.service.spec.ts asserts the
 * "never leak" property for the exact scenario in spec Section 6.3.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { Injectable } from '@nestjs/common';

/** All possible scope tokens the platform recognizes. */
export type ConsentScope =
  | 'identity:name_only'
  | 'identity:full'
  | 'earnings:monthly_aggregate'
  | 'earnings:annual_summary'
  | 'reputation:composite_score'
  | 'reputation:full_breakdown'
  | 'skills:verified_list'
  | 'verification:platform_status';

/**
 * Fields that are FORBIDDEN from ever appearing in a verification response,
 * regardless of any scope. These are absolute blocklist entries.
 * (Section 6.3 explicit examples + reasonable extensions)
 */
const ABSOLUTE_FORBIDDEN_FIELDS = new Set([
  'residential_address',
  'street_address',
  'address_line1',
  'address_line2',
  'city',
  'state',
  'zip_code',
  'postal_code',
  'phone_number',
  'phone',
  'mobile',
  'national_id',
  'tax_id',
  'ssn',
  'tin',
  'national_tax_identifier',
  'government_id',
  'passport_number',
  'oauth_token',
  'access_token',
  'refresh_token',
  'platform_token',
  'raw_oauth',
  'documents',
  'uploaded_documents',
  'document_urls',
  'platform_credentials',
  'private_key',
  'password',
  'password_hash',
  // Earnings detail that requires explicit scope
  'hourly_breakdown',
  'daily_breakdown',
  'platform_earnings_detail',
  'raw_earnings',
  'earnings_by_job',
]);

/**
 * Scope → allowed field names mapping.
 * A field appears in the response ONLY if its scope is in permitted_scopes.
 * Fields not listed here for any scope NEVER appear.
 */
const SCOPE_FIELD_MAP: Record<string, string[]> = {
  'identity:name_only': ['legal_name'],
  'identity:full': ['legal_name', 'display_name', 'profile_photo_url'],
  'earnings:monthly_aggregate': [
    'earnings_monthly_aggregate',
    'currency',
    'earnings_period',
  ],
  'earnings:annual_summary': [
    'earnings_annual_total',
    'currency',
    'earnings_year',
    'top_platform',
  ],
  'reputation:composite_score': [
    'composite_score',
    'confidence_tier',
    'confidence_index',
  ],
  'reputation:full_breakdown': [
    'composite_score',
    'confidence_tier',
    'confidence_index',
    'rating_subscore',
    'volume_subscore',
    'reliability_subscore',
    'consistency_subscore',
    'skills_subscore',
  ],
  'skills:verified_list': ['verified_skills'],
  'verification:platform_status': [
    'connected_platforms',
    'platform_verification_status',
    'is_identity_verified',
  ],
};

/** The complete raw worker data shape that the query returns. */
export interface RawWorkerData {
  // Identity
  legal_name?: string;
  display_name?: string;
  profile_photo_url?: string;
  // Earnings
  earnings_monthly_aggregate?: number;
  earnings_annual_total?: number;
  currency?: string;
  earnings_period?: string;
  earnings_year?: number;
  top_platform?: string;
  // Reputation
  composite_score?: number;
  confidence_tier?: string;
  confidence_index?: number;
  rating_subscore?: number;
  volume_subscore?: number;
  reliability_subscore?: number;
  consistency_subscore?: number;
  skills_subscore?: number;
  // Skills
  verified_skills?: string[];
  // Verification status
  connected_platforms?: string[];
  platform_verification_status?: Record<string, boolean>;
  is_identity_verified?: boolean;
  // DANGER ZONE — these must NEVER appear in output
  residential_address?: string;
  phone_number?: string;
  tax_id?: string;
  oauth_token?: string;
  documents?: unknown[];
  [key: string]: unknown;
}

/** Result of projection — only consented, allowed fields. */
export type ProjectedWorkerData = Record<string, unknown>;

@Injectable()
export class ProjectionService {
  /**
   * Builds the projection field allowlist from the permitted scopes.
   * Only fields listed in SCOPE_FIELD_MAP for the granted scopes are allowed.
   */
  buildAllowedFields(permittedScopes: string[]): Set<string> {
    const allowed = new Set<string>();
    for (const scope of permittedScopes) {
      const fields = SCOPE_FIELD_MAP[scope] ?? [];
      for (const field of fields) {
        allowed.add(field);
      }
    }
    return allowed;
  }

  /**
   * Projects raw worker data through the consent scope filter.
   *
   * Algorithm (scope-driven, not post-hoc strip):
   *   1. Build the allowed field set from scopes.
   *   2. Iterate over allowed fields only — never start from raw data keys.
   *   3. For each allowed field, copy the value if it exists in rawData.
   *   4. Double-check against ABSOLUTE_FORBIDDEN_FIELDS (defense-in-depth).
   *
   * A field that is not in `allowed` will NEVER appear in the output,
   * regardless of what rawData contains.
   */
  project(
    rawData: RawWorkerData,
    permittedScopes: string[],
  ): ProjectedWorkerData {
    const allowed = this.buildAllowedFields(permittedScopes);
    const result: ProjectedWorkerData = {};

    // Iterate ONLY over allowed fields — never rawData's own keys
    for (const field of allowed) {
      // Defense-in-depth: enforce absolute blocklist even if SCOPE_FIELD_MAP
      // was accidentally updated to include a forbidden field
      if (ABSOLUTE_FORBIDDEN_FIELDS.has(field)) {
        // This should never happen if SCOPE_FIELD_MAP is correct,
        // but we log it as a security alert.
        console.error(
          `SECURITY ALERT: Field "${field}" is in ABSOLUTE_FORBIDDEN_FIELDS ` +
            'but was included in SCOPE_FIELD_MAP. It has been suppressed.',
        );
        continue;
      }

      if (field in rawData && rawData[field] !== undefined) {
        result[field] = rawData[field];
      }
    }

    return result;
  }

  /**
   * Maps scoped projected data into the verification response worker shape.
   * Wraps projected fields with appropriate structure for the API response.
   */
  buildVerificationWorkerResponse(
    projected: ProjectedWorkerData,
  ): Record<string, unknown> {
    // The projected data is already field-filtered.
    // Wrap into the worker sub-object of the verification response.
    return { ...projected };
  }

  /**
   * Maps scoped projected data into the verified_metrics response shape.
   * Only numeric/performance metrics fields end up here.
   */
  buildVerifiedMetrics(
    projected: ProjectedWorkerData,
  ): Record<string, unknown> {
    const metricsFields = new Set([
      'composite_score', 'confidence_tier', 'confidence_index',
      'rating_subscore', 'volume_subscore', 'reliability_subscore',
      'consistency_subscore', 'skills_subscore',
      'earnings_monthly_aggregate', 'earnings_annual_total',
      'currency', 'earnings_period', 'earnings_year',
    ]);

    const metrics: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(projected)) {
      if (metricsFields.has(key)) {
        metrics[key] = value;
      }
    }
    return metrics;
  }
}

// Re-export the forbidden fields for testing
export { ABSOLUTE_FORBIDDEN_FIELDS, SCOPE_FIELD_MAP };
