import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AccessAuditLog } from './entities/access-audit-log.entity';
import { AuditService } from './audit.service';

@Module({
  imports: [TypeOrmModule.forFeature([AccessAuditLog])],
  providers: [AuditService],
  exports: [AuditService],
})
export class AuditModule {}
