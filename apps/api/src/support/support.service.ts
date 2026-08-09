import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SupportService {
  constructor(private readonly prisma: PrismaService) {}

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

    return this.prisma.supportConversation.findUnique({
      where: {
        id: conversationId,
      },
    });
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
}
