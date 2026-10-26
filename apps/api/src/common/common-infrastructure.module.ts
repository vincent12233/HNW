import { Global, Module } from '@nestjs/common';
import { RedisHealthService } from './redis-health.service';
import { RedisLeaseService } from './redis-lease.service';

@Global()
@Module({
  providers: [RedisHealthService, RedisLeaseService],
  exports: [RedisHealthService, RedisLeaseService],
})
export class CommonInfrastructureModule {}
