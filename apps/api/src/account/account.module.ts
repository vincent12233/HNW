import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RolesGuard } from '../auth/roles.guard';
import { PrismaModule } from '../prisma/prisma.module';
import { AccountController } from './account.controller';
import { AccountService } from './account.service';
import { AdminAccountController } from './admin-account.controller';
import { AdminAccountService } from './admin-account.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [AccountController, AdminAccountController],
  providers: [AccountService, AdminAccountService, RolesGuard],
})
export class AccountModule {}
