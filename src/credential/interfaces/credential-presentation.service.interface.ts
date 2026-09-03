/**
 * credential-presentation.service.interface.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * INTERFACE CONTRACT for SD-JWT credential presentation assembly.
 *
 * Developer 3 (this code) DEFINES this interface and CALLS it.
 * Developer 2 IMPLEMENTS it with real ECDSA/SD-JWT cryptographic signing.
 *
 * Why an interface (not abstract class)?
 *   - Allows Developer 2 to provide any concrete implementation without
 *     inheriting NestJS-specific coupling.
 *   - The injection token (CREDENTIAL_PRESENTATION_SERVICE) is used so
 *     Developer 2's implementation can be swapped in via DI without changing
 *     callers.
 *
 * IMPORTANT: Developer 3 must NEVER implement ECDSA signing, salt/digest
 * generation, or JWKS handling. Those cryptographic operations belong to
 * Developer 2 exclusively, per spec Section 2 Hard Constraints.
 * ─────────────────────────────────────────────────────────────────────────────
 */

/** DI injection token. Use this token when providing/injecting the service. */
export const CREDENTIAL_PRESENTATION_SERVICE = Symbol(
  'CredentialPresentationService',
);

/**
 * A single claim/attribute to be disclosed in the SD-JWT presentation.
 * Claims are derived from the worker's consented scopes.
 */
export interface CredentialClaim {
  /** Claim namespace, e.g. 'identity', 'earnings', 'reputation' */
  namespace: string;
  /** Claim key within the namespace, e.g. 'legal_name', 'monthly_aggregate' */
  key: string;
  /** The consented, redacted value of this claim. */
  value: unknown;
}

/**
 * Consent context binding the presentation to a specific authorization.
 * Key-binds the SD-JWT to a verifier nonce (prevents replay attacks).
 */
export interface PresentationConsentContext {
  /** UUID of the consent_records row authorizing this presentation. */
  consent_record_id: string;
  /** UUID of the share_links row through which access was granted. */
  share_link_id: string;
  /** Scopes explicitly authorized in the consent record. */
  authorized_scopes: string[];
}

/**
 * Full input to the credential presentation assembly pipeline.
 *
 * Developer 3 constructs this after:
 *   1. Token resolution (share_links lookup)
 *   2. Scope evaluation (consent_records lookup)
 *   3. Data projection (only consented fields selected)
 */
export interface CredentialPresentationInput {
  /**
   * Consented claims — already redacted by ProjectionService.
   * ONLY fields the worker has consented to share are included.
   */
  claims: CredentialClaim[];

  /**
   * Worker identity data (already projected to consented fields only).
   * This is the same data that will appear in the response body, passed
   * through for SD-JWT claim binding.
   */
  worker_data: Record<string, unknown>;

  /**
   * Verifier-supplied nonce for key-binding (replay protection).
   * Must be bound into the KB-JWT portion of the SD-JWT presentation.
   */
  verifier_nonce: string;

  /** Consent and share-link context for binding the presentation. */
  consent_context: PresentationConsentContext;

  /**
   * Worker's DID or public key material, provided by Developer 2's
   * identity infrastructure. Used for holder binding in the SD-JWT.
   */
  holder_public_key?: Record<string, unknown>;
}

/**
 * CredentialPresentationService interface.
 *
 * Developer 2 must provide a concrete class implementing this interface
 * and register it under the CREDENTIAL_PRESENTATION_SERVICE injection token.
 *
 * Example NestJS provider registration (in Developer 2's module):
 * ```typescript
 * {
 *   provide: CREDENTIAL_PRESENTATION_SERVICE,
 *   useClass: SdJwtPresentationService,  // Developer 2's implementation
 * }
 * ```
 */
export interface ICredentialPresentationService {
  /**
   * Assembles a compact SD-JWT presentation string containing only the
   * disclosures matching consented scopes, key-bound to the verifier nonce.
   *
   * @param input - Consented claims, redacted worker data, nonce, and consent context.
   * @returns A compact SD-JWT presentation string (issuer-signed-jwt~disclosure1~disclosure2~KB-JWT)
   *
   * @throws If signing fails, the credential cannot be constructed, or the
   *         verifier nonce is missing/invalid.
   */
  assemblePresentation(input: CredentialPresentationInput): Promise<string>;
}

/**
 * STUB implementation for development and testing.
 * Returns a clearly-labeled placeholder string.
 * Developer 2 replaces this with real SD-JWT signing.
 */
export class StubCredentialPresentationService
  implements ICredentialPresentationService
{
  async assemblePresentation(
    input: CredentialPresentationInput,
  ): Promise<string> {
    // STUB: Returns a base64url-encoded JSON mimicking SD-JWT structure.
    // Real implementation must use ECDSA signing over the SD-JWT VC spec.
    const payload = {
      _stub: true,
      claims: input.claims,
      nonce: input.verifier_nonce,
      consent: input.consent_context,
      iat: Math.floor(Date.now() / 1000),
    };
    const encoded = Buffer.from(JSON.stringify(payload)).toString('base64url');
    return `eyJhbGciOiJFUzI1NiJ9.${encoded}.STUB_SIGNATURE~STUB_DISCLOSURE~`;
  }
}
