import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ApprovalModule } from '../approval/approval.module';
import { RolesGuard } from '../auth/roles.guard';
import { PrismaModule } from '../prisma/prisma.module';
import { AccountController } from './account.controller';
import { AccountService } from './account.service';
import { AdminAccountController } from './admin-account.controller';
import { AdminAccountService } from './admin-account.service';

@Module({
  imports: [AuthModule, PrismaModule, ApprovalModule],
  controllers: [AccountController, AdminAccountController],
  providers: [AccountService, AdminAccountService, RolesGuard],
})
export class AccountModule {}
