import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

@Injectable()
export class SupportService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async createConversation(clientId: string) {
    const existing = await this.prisma.supportConversation.findFirst({
      where: {
        clientId,
        status: 'OPEN',
      },
      orderBy: {
        updatedAt: 'desc',
      },
    });

    if (existing) {
      return existing;
    }

    return this.prisma.supportConversation.create({
      data: {
        clientId,
      },
    });
  }

  async listClientConversations(clientId: string) {
    return this.prisma.supportConversation.findMany({
      where: {
        clientId,
      },
      include: {
        messages: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async listOpenConversations() {
    return this.prisma.supportConversation.findMany({
      include: {
        client: {
          select: {
            id: true,
            customerNo: true,
            fullName: true,
            phone: true,
          },
        },
        messages: {
          orderBy: {
            createdAt: 'desc',
          },
          take: 1,
        },
      },
      orderBy: {
        updatedAt: 'desc',
      },
    });
  }

  async updateTags(conversationId: string, tags: string[]) {
    const normalizedTags = Array.from(
      new Set(
        (tags || [])
          .map((tag) => tag.trim())
          .filter(Boolean)
          .map((tag) => tag.slice(0, 24)),
      ),
    );

    if (normalizedTags.length > 12) {
      throw new BadRequestException('每个会话最多设置 12 个标签');
    }

    const updated = await this.prisma.supportConversation.updateMany({
      where: {
        id: conversationId,
      },
      data: {
        tags: normalizedTags,
      },
    });

    if (updated.count !== 1) {
      throw new NotFoundException('未找到客服会话');
    }

    return this.prisma.supportConversation.findUnique({
      where: {
        id: conversationId,
      },
    });
  }

  async updateMeta(
    conversationId: string,
    body: { internalNote?: string; priority?: string; status?: 'OPEN' | 'CLOSED' },
    actorId?: string,
  ) {
    const updated = await this.prisma.supportConversation.updateMany({
      where: {
        id: conversationId,
      },
      data: {
        ...(body.internalNote !== undefined
          ? { internalNote: body.internalNote.trim().slice(0, 1000) }
          : {}),
        ...(body.priority ? { priority: body.priority.trim().slice(0, 16) } : {}),
        ...(body.status ? { status: body.status } : {}),
      },
    });

    if (updated.count !== 1) {
      throw new NotFoundException('未找到客服会话');
    }

    const conversation = await this.prisma.supportConversation.findUnique({
      where: {
        id: conversationId,
      },
    });

    await this.auditService.createLog({
      actorId,
      action: 'SUPPORT_CONVERSATION_META_UPDATE',
      resource: 'support_conversation',
      resourceId: conversationId,
      description: '更新客服会话备注/优先级/状态',
      metadata: body,
    });

    return conversation;
  }

  async sendMessage(
    conversationId: string,
    senderId: string,
    senderRole: UserRole,
    content: string,
  ) {
    const trimmedContent = content?.trim();

    if (!trimmedContent) {
      throw new BadRequestException('消息内容不能为空');
    }

    const conversation = await this.prisma.supportConversation.findUnique({
      where: {
        id: conversationId,
      },
      select: {
        id: true,
        clientId: true,
        status: true,
      },
    });

    if (!conversation) {
      throw new NotFoundException('未找到客服会话');
    }

    if (senderRole === UserRole.CLIENT && conversation.clientId !== senderId) {
      throw new ForbiddenException('无权访问该客服会话');
    }

    const senderType =
      senderRole === UserRole.CLIENT
        ? 'CLIENT'
        : senderRole === UserRole.ADMIN
          ? 'ADMIN'
          : 'SUPPORT';

    const message = await this.prisma.supportMessage.create({
      data: {
        conversationId,
        senderId,
        senderType,
        content: trimmedContent,
      },
    });

    await this.prisma.supportConversation.update({
      where: {
        id: conversationId,
      },
      data: {
        updatedAt: new Date(),
      },
    });

    return message;
  }

  async getMessages(conversationId: string, userId: string, role: UserRole) {
    const conversation = await this.prisma.supportConversation.findUnique({
      where: {
        id: conversationId,
      },
      select: {
        clientId: true,
      },
    });

    if (!conversation) {
      throw new NotFoundException('未找到客服会话');
    }

    if (role === UserRole.CLIENT && conversation.clientId !== userId) {
      throw new ForbiddenException('无权访问该客服会话');
    }

    return this.prisma.supportMessage.findMany({
      where: {
        conversationId,
      },
      include: {
        sender: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            role: true,
          },
        },
      },
      orderBy: {
        createdAt: 'asc',
      },
    });
  }

  translateMessage(content: string) {
    const trimmedContent = content.trim();

    if (!trimmedContent) {
      throw new BadRequestException('翻译内容不能为空');
    }

    const lower = trimmedContent.toLowerCase();
    let summary: string;
    let suggestedReply: string;

    if (lower.includes('deposit') || lower.includes('recharge')) {
      summary = '客户在咨询入金/充值。';
      suggestedReply =
        '请提供付款凭证和充值金额，客服确认后会转交财务为账户上分。';
    } else if (lower.includes('withdraw')) {
      summary = '客户在咨询提现。';
      suggestedReply = '请提供提现订单号，财务会核对并处理。';
    } else if (
      lower.includes('kyc') ||
      lower.includes('aadhaar') ||
      lower.includes('pan')
    ) {
      summary = '客户在咨询 KYC。';
      suggestedReply =
        '请上传清晰的 Aadhaar 或 PAN 文件，业务员会尽快审核。';
    } else if (/[\u4e00-\u9fff]/.test(trimmedContent)) {
      summary = '检测到中文消息。';
      suggestedReply = '请根据客户内容回复英文，必要时转交会英语的客服继续处理。';
    } else {
      summary = '未匹配到固定业务关键词。';
      suggestedReply = '请结合客户原文、手机号和客户编号继续核查。';
    }

    return {
      sourceText: trimmedContent,
      summary,
      suggestedReply,
      translatedText: `${summary}${suggestedReply}`,
      provider: 'INTERNAL_RULES',
    };
  }
}
