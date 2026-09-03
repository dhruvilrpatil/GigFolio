import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { ShareLink } from './entities/share-link.entity';
import { ConsentRecord } from './entities/consent-record.entity';
import { ShareLinkService } from './share-link.service';
import { QrService } from './qr.service';
import { ConsentController } from './consent.controller';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([ShareLink, ConsentRecord]),
    ConfigModule,
    AuditModule,
  ],
  controllers: [ConsentController],
  providers: [ShareLinkService, QrService],
  exports: [ShareLinkService],
})
export class ConsentModule {}
