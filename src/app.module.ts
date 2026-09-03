/**
 * app.module.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Root application module wiring all Developer 3 modules with shared
 * infrastructure (TypeORM, BullMQ, Redis, Config).
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bullmq';
import { ReputationModule } from './reputation/reputation.module';
import { ConsentModule } from './consent/consent.module';
import { VerificationModule } from './verification/verification.module';
import { AuditModule } from './audit/audit.module';
import { CredentialModule } from './credential/credential.module';
import { PublicProfileModule } from './public-profile/public-profile.module';

// Entities
import { ReputationScore } from './reputation/entities/reputation-score.entity';
import { ShareLink } from './consent/entities/share-link.entity';
import { ConsentRecord } from './consent/entities/consent-record.entity';
import { AccessAuditLog } from './audit/entities/access-audit-log.entity';
import { Organization, OrganizationKey } from './verification/entities/organization-key.entity';
import { WorkerPublicProfile } from './public-profile/entities/worker-public-profile.entity';

@Module({
  imports: [
    // ── Configuration ─────────────────────────────────────────────────────
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.local', '.env'],
    }),

    // ── PostgreSQL (Developer 1 owns the schema; we consume it) ───────────
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get<string>('DB_HOST', 'localhost'),
        port: config.get<number>('DB_PORT', 5432),
        username: config.get<string>('DB_USER', 'gigfolio'),
        password: config.get<string>('DB_PASSWORD', 'gigfolio'),
        database: config.get<string>('DB_NAME', 'gigfolio'),
        entities: [
          ReputationScore,
          ShareLink,
          ConsentRecord,
          AccessAuditLog,
          Organization,
          OrganizationKey,
          WorkerPublicProfile,
        ],
        // NEVER run migrations automatically — Developer 1 owns schema migrations.
        synchronize: false,
        logging: config.get<string>('NODE_ENV') === 'development',
        ssl: config.get<string>('NODE_ENV') === 'production'
          ? { rejectUnauthorized: true }
          : false,
      }),
    }),

    // ── Redis + BullMQ (Developer 1 owns Redis infra; we consume it) ──────
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        connection: {
          host: config.get<string>('REDIS_HOST', 'localhost'),
          port: config.get<number>('REDIS_PORT', 6379),
          password: config.get<string>('REDIS_PASSWORD'),
          tls: config.get<string>('NODE_ENV') === 'production' ? {} : undefined,
        },
      }),
    }),

    // ── Domain Modules ────────────────────────────────────────────────────
    AuditModule,
    CredentialModule,
    ReputationModule,
    ConsentModule,
    VerificationModule,
    PublicProfileModule,
  ],
})
export class AppModule {}
