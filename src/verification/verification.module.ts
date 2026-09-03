import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Organization, OrganizationKey } from './entities/organization-key.entity';
import { ShareLink } from '../consent/entities/share-link.entity';
import { ConsentRecord } from '../consent/entities/consent-record.entity';
import { ProjectionService } from './projection.service';
import { VerificationService } from './verification.service';
import { VerificationController } from './verification.controller';
import { OrgApiKeyGuard } from '../common/guards/org-api-key.guard';
import { ConsentModule } from '../consent/consent.module';
import { AuditModule } from '../audit/audit.module';
import { CredentialModule } from '../credential/credential.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Organization, OrganizationKey, ShareLink, ConsentRecord]),
    ConsentModule,
    AuditModule,
    CredentialModule,
  ],
  controllers: [VerificationController],
  providers: [ProjectionService, VerificationService, OrgApiKeyGuard],
})
export class VerificationModule {}
