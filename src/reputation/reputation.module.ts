/**
 * reputation.module.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Self-contained reputation module. Can be extracted to its own service later.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bullmq';
import { ReputationScore } from './entities/reputation-score.entity';
import { ReputationRepository } from './reputation.repository';
import { ReputationService } from './reputation.service';
import { ReputationWorker, REPUTATION_QUEUE } from './reputation.worker';
import { ReputationController } from './reputation.controller';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([ReputationScore]),
    BullModule.registerQueue({
      name: REPUTATION_QUEUE,
      defaultJobOptions: {
        attempts: 5,
        backoff: {
          type: 'exponential',
          delay: 2000,
        },
        removeOnComplete: 100,
        removeOnFail: 500,
      },
    }),
    AuditModule,
  ],
  controllers: [ReputationController],
  providers: [ReputationRepository, ReputationService, ReputationWorker],
  exports: [ReputationService],
})
export class ReputationModule {}
