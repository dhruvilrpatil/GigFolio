import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WorkerPublicProfile } from './entities/worker-public-profile.entity';
import { PublicProfileService } from './public-profile.service';
import {
  PublicProfileController,
  WorkerSettingsController,
} from './public-profile.controller';
import { AuditModule } from '../audit/audit.module';
import { OrganizationKey, Organization } from '../verification/entities/organization-key.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([WorkerPublicProfile, OrganizationKey, Organization]),
    AuditModule,
  ],
  controllers: [PublicProfileController, WorkerSettingsController],
  providers: [PublicProfileService],
  exports: [PublicProfileService],
})
export class PublicProfileModule {}
