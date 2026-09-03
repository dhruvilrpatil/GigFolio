import { Module } from '@nestjs/common';
import {
  CREDENTIAL_PRESENTATION_SERVICE,
  StubCredentialPresentationService,
} from './interfaces/credential-presentation.service.interface';

/**
 * CredentialModule
 * ─────────────────────────────────────────────────────────────────────────────
 * Provides the CredentialPresentationService injection token.
 *
 * In development/testing: uses StubCredentialPresentationService.
 * In production: Developer 2 replaces the provider with their SD-JWT implementation.
 *
 * To integrate Developer 2's implementation:
 *   Replace `useClass: StubCredentialPresentationService`
 *   with    `useClass: SdJwtPresentationService` from Dev 2's module.
 * ─────────────────────────────────────────────────────────────────────────────
 */
@Module({
  providers: [
    {
      provide: CREDENTIAL_PRESENTATION_SERVICE,
      useClass: StubCredentialPresentationService,
    },
  ],
  exports: [CREDENTIAL_PRESENTATION_SERVICE],
})
export class CredentialModule {}
