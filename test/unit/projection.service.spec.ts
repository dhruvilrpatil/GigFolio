/**
 * projection.service.spec.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests proving the "never leak unconsented fields" property.
 *
 * Required by spec Section 6.3 and Section 9:
 *   "Write a unit test that asserts this explicitly for at least the exact
 *   scenario in Section 6.3."
 *
 * The exact scenario tested:
 *   Consented scopes: ['identity:name_only', 'earnings:monthly_aggregate', 'reputation:composite_score']
 *   Must NOT appear in response: residential_address, phone_number, national_tax_identifier,
 *   raw OAuth tokens, private uploaded documents, non-consented earnings breakdown.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { describe, it, expect, beforeEach } from 'vitest';
import {
  ProjectionService,
  RawWorkerData,
  ABSOLUTE_FORBIDDEN_FIELDS,
  SCOPE_FIELD_MAP,
} from '../../src/verification/projection.service';

// ── Test Fixtures ─────────────────────────────────────────────────────────────

/**
 * A "maximally dangerous" raw data object that contains ALL possible sensitive fields.
 * The projection service must prevent ALL of these from leaking.
 */
const DANGEROUS_RAW_DATA: RawWorkerData = {
  // Consented fields (should appear for correct scopes)
  legal_name: 'Jane Worker',
  earnings_monthly_aggregate: 3200,
  currency: 'USD',
  earnings_period: '2026-09',
  composite_score: 782,
  confidence_tier: 'HIGH_CONFIDENCE',
  confidence_index: 0.86,
  rating_subscore: 0.91,
  volume_subscore: 0.77,
  reliability_subscore: 0.94,
  consistency_subscore: 0.68,
  skills_subscore: 0.50,

  // ── DANGEROUS FIELDS (must NEVER appear in output) ──────────────────────────
  residential_address: '123 Private Lane, Springfield, IL 62701',
  street_address: '123 Private Lane',
  address_line1: '123 Private Lane',
  city: 'Springfield',
  state: 'IL',
  zip_code: '62701',
  phone_number: '+1-555-0123',
  phone: '+1-555-0123',
  mobile: '+1-555-0123',
  national_id: 'US-123456789',
  tax_id: '987-65-4321',
  ssn: '987-65-4321',
  tin: '987-65-4321',
  national_tax_identifier: '987-65-4321',
  government_id: 'G-987654321',
  passport_number: 'P-123456789',
  oauth_token: 'ya29.UBER_OAUTH_SECRET_TOKEN',
  access_token: 'uber_access_token_secret',
  refresh_token: 'uber_refresh_token_secret',
  platform_token: 'doordash_platform_secret',
  raw_oauth: '{"uber": "secret_oauth_data"}',
  documents: [
    { type: 'drivers_license', url: 'https://private-docs.example.com/dl.pdf' },
    { type: 'background_check', url: 'https://private-docs.example.com/bg.pdf' },
  ],
  uploaded_documents: ['doc1.pdf', 'doc2.pdf'],
  document_urls: ['https://private.example.com/doc1'],
  platform_credentials: { uber: 'uber_secret', doordash: 'dd_secret' },
  hourly_breakdown: { '09:00': 45.50, '10:00': 38.25 },
  daily_breakdown: { '2026-09-01': 450.00 },
  platform_earnings_detail: { uber: 1200, doordash: 800 },
  raw_earnings: [{ date: '2026-09-01', amount: 450 }],
  earnings_by_job: [{ job_id: 'j001', amount: 25 }],

  // Additional non-consented data
  email: 'jane@private.com',
  date_of_birth: '1990-01-15',
  bank_account_number: '****-****-****-1234',
};

// ── Test Suite ─────────────────────────────────────────────────────────────────

describe('ProjectionService — consent boundary enforcement', () => {
  let service: ProjectionService;

  beforeEach(() => {
    service = new ProjectionService();
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION A — The Exact Section 6.3 Scenario
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('Section 6.3 exact scenario: identity:name_only + earnings:monthly_aggregate + reputation:composite_score', () => {
    const CONSENTED_SCOPES = [
      'identity:name_only',
      'earnings:monthly_aggregate',
      'reputation:composite_score',
    ];

    let result: ReturnType<ProjectionService['project']>;

    beforeEach(() => {
      result = service.project(DANGEROUS_RAW_DATA, CONSENTED_SCOPES);
    });

    // ── Consented fields MUST appear ────────────────────────────────────────
    it('includes legal_name (from identity:name_only)', () => {
      expect(result).toHaveProperty('legal_name', 'Jane Worker');
    });

    it('includes earnings_monthly_aggregate (from earnings:monthly_aggregate)', () => {
      expect(result).toHaveProperty('earnings_monthly_aggregate', 3200);
    });

    it('includes composite_score (from reputation:composite_score)', () => {
      expect(result).toHaveProperty('composite_score', 782);
    });

    // ── Address — must NEVER leak ───────────────────────────────────────────
    it('NEVER contains residential_address', () => {
      expect(result).not.toHaveProperty('residential_address');
    });

    it('NEVER contains street_address', () => {
      expect(result).not.toHaveProperty('street_address');
    });

    it('NEVER contains address_line1', () => {
      expect(result).not.toHaveProperty('address_line1');
    });

    it('NEVER contains city, state, zip_code', () => {
      expect(result).not.toHaveProperty('city');
      expect(result).not.toHaveProperty('state');
      expect(result).not.toHaveProperty('zip_code');
    });

    // ── Phone — must NEVER leak ─────────────────────────────────────────────
    it('NEVER contains phone_number', () => {
      expect(result).not.toHaveProperty('phone_number');
    });

    it('NEVER contains phone or mobile', () => {
      expect(result).not.toHaveProperty('phone');
      expect(result).not.toHaveProperty('mobile');
    });

    // ── National tax identifier / SSN / TIN — must NEVER leak ──────────────
    it('NEVER contains national_tax_identifier', () => {
      expect(result).not.toHaveProperty('national_tax_identifier');
    });

    it('NEVER contains tax_id', () => {
      expect(result).not.toHaveProperty('tax_id');
    });

    it('NEVER contains ssn', () => {
      expect(result).not.toHaveProperty('ssn');
    });

    it('NEVER contains tin', () => {
      expect(result).not.toHaveProperty('tin');
    });

    it('NEVER contains national_id or government_id', () => {
      expect(result).not.toHaveProperty('national_id');
      expect(result).not.toHaveProperty('government_id');
    });

    it('NEVER contains passport_number', () => {
      expect(result).not.toHaveProperty('passport_number');
    });

    // ── Raw OAuth tokens — must NEVER leak ──────────────────────────────────
    it('NEVER contains oauth_token', () => {
      expect(result).not.toHaveProperty('oauth_token');
    });

    it('NEVER contains access_token or refresh_token', () => {
      expect(result).not.toHaveProperty('access_token');
      expect(result).not.toHaveProperty('refresh_token');
    });

    it('NEVER contains platform_token or raw_oauth', () => {
      expect(result).not.toHaveProperty('platform_token');
      expect(result).not.toHaveProperty('raw_oauth');
    });

    it('NEVER contains platform_credentials', () => {
      expect(result).not.toHaveProperty('platform_credentials');
    });

    // ── Documents — must NEVER leak ──────────────────────────────────────────
    it('NEVER contains documents', () => {
      expect(result).not.toHaveProperty('documents');
    });

    it('NEVER contains uploaded_documents', () => {
      expect(result).not.toHaveProperty('uploaded_documents');
    });

    it('NEVER contains document_urls', () => {
      expect(result).not.toHaveProperty('document_urls');
    });

    // ── Non-consented earnings breakdown — must NEVER leak ────────────────────
    it('NEVER contains hourly_breakdown', () => {
      expect(result).not.toHaveProperty('hourly_breakdown');
    });

    it('NEVER contains daily_breakdown', () => {
      expect(result).not.toHaveProperty('daily_breakdown');
    });

    it('NEVER contains platform_earnings_detail', () => {
      expect(result).not.toHaveProperty('platform_earnings_detail');
    });

    it('NEVER contains raw_earnings or earnings_by_job', () => {
      expect(result).not.toHaveProperty('raw_earnings');
      expect(result).not.toHaveProperty('earnings_by_job');
    });

    // ── Other non-consented fields ────────────────────────────────────────────
    it('NEVER contains email', () => {
      expect(result).not.toHaveProperty('email');
    });

    it('NEVER contains date_of_birth', () => {
      expect(result).not.toHaveProperty('date_of_birth');
    });

    it('NEVER contains bank_account_number', () => {
      expect(result).not.toHaveProperty('bank_account_number');
    });

    // ── Output key count sanity check ────────────────────────────────────────
    it('output contains ONLY the expected allowed fields and nothing else', () => {
      const allowedKeys = new Set([
        'legal_name',                     // identity:name_only
        'earnings_monthly_aggregate',     // earnings:monthly_aggregate
        'currency',                       // earnings:monthly_aggregate
        'earnings_period',                // earnings:monthly_aggregate
        'composite_score',               // reputation:composite_score
        'confidence_tier',               // reputation:composite_score
        'confidence_index',              // reputation:composite_score
      ]);
      for (const key of Object.keys(result)) {
        expect(allowedKeys).toContain(key);
      }
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION B — Empty scopes → nothing leaks
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('Empty scopes — nothing should appear in output', () => {
    it('returns empty object for empty scopes', () => {
      const result = service.project(DANGEROUS_RAW_DATA, []);
      expect(Object.keys(result)).toHaveLength(0);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION C — ABSOLUTE_FORBIDDEN_FIELDS integrity check
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('ABSOLUTE_FORBIDDEN_FIELDS — must be complete', () => {
    const EXPECTED_FORBIDDEN = [
      'residential_address', 'phone_number', 'tax_id', 'ssn', 'tin',
      'national_tax_identifier', 'oauth_token', 'access_token', 'refresh_token',
      'documents', 'uploaded_documents',
    ];

    it.each(EXPECTED_FORBIDDEN)(
      'ABSOLUTE_FORBIDDEN_FIELDS contains "%s"',
      (field) => {
        expect(ABSOLUTE_FORBIDDEN_FIELDS.has(field)).toBe(true);
      },
    );
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION D — SCOPE_FIELD_MAP integrity: no forbidden field can be in any scope
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('SCOPE_FIELD_MAP integrity', () => {
    it('no field in SCOPE_FIELD_MAP should be in ABSOLUTE_FORBIDDEN_FIELDS', () => {
      for (const [scope, fields] of Object.entries(SCOPE_FIELD_MAP)) {
        for (const field of fields) {
          expect(
            ABSOLUTE_FORBIDDEN_FIELDS.has(field),
            `Scope "${scope}" maps to forbidden field "${field}"`,
          ).toBe(false);
        }
      }
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SECTION E — Single scope isolation
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  describe('identity:name_only scope', () => {
    it('returns only legal_name and nothing else', () => {
      const result = service.project(DANGEROUS_RAW_DATA, ['identity:name_only']);
      expect(Object.keys(result)).toEqual(['legal_name']);
      expect(result.legal_name).toBe('Jane Worker');
    });
  });

  describe('reputation:composite_score scope', () => {
    it('returns composite_score, confidence_tier, confidence_index only', () => {
      const result = service.project(DANGEROUS_RAW_DATA, ['reputation:composite_score']);
      const keys = Object.keys(result);
      expect(keys).toContain('composite_score');
      expect(keys).toContain('confidence_tier');
      expect(keys).toContain('confidence_index');
      // Must not contain sub-scores (those need reputation:full_breakdown)
      expect(keys).not.toContain('rating_subscore');
      expect(keys).not.toContain('volume_subscore');
    });
  });

  describe('reputation:full_breakdown scope', () => {
    it('returns all sub-scores in addition to composite', () => {
      const result = service.project(DANGEROUS_RAW_DATA, ['reputation:full_breakdown']);
      const keys = Object.keys(result);
      expect(keys).toContain('rating_subscore');
      expect(keys).toContain('volume_subscore');
      expect(keys).toContain('reliability_subscore');
      // Still must NOT contain forbidden fields
      expect(keys).not.toContain('tax_id');
      expect(keys).not.toContain('phone_number');
    });
  });
});
