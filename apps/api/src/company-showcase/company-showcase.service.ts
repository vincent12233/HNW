import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

type ShowcaseBody = Record<string, unknown>;

@Injectable()
export class CompanyShowcaseService {
  constructor(private readonly prisma: PrismaService) {}
  listPublic() {
    return this.prisma.companyShowcase.findMany({
      where: { status: 'ACTIVE' },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      take: 1,
    });
  }
  listAll() {
    return this.prisma.companyShowcase.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }
  private text(value: unknown, fallback = ''): string {
    if (typeof value === 'string') return value.trim() || fallback;
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value).trim() || fallback;
    }
    return fallback;
  }
  private optionalText(value: unknown): string | null {
    if (value == null) return null;
    if (typeof value === 'string') return value.trim() || null;
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value).trim() || null;
    }
    return null;
  }
  private data(body: ShowcaseBody) {
    const name = this.text(body.name);
    const tagline = this.text(body.tagline);
    const description = this.text(body.description);
    if (!name || !tagline || !description)
      throw new BadRequestException(
        'Name, tagline and description are required',
      );
    return {
      name,
      tagline,
      description,
      logoUrl: this.optionalText(body.logoUrl),
      videoUrl: this.optionalText(body.videoUrl),
      websiteUrl: this.optionalText(body.websiteUrl),
      sector: this.optionalText(body.sector),
      status: body.status === 'INACTIVE' ? 'INACTIVE' : 'ACTIVE',
      sortOrder: Number.isFinite(Number(body.sortOrder))
        ? Number(body.sortOrder)
        : 0,
    };
  }
  async create(body: ShowcaseBody) {
    const existing = await this.prisma.companyShowcase.findFirst({
      orderBy: { createdAt: 'asc' },
    });
    if (existing)
      return this.prisma.companyShowcase.update({
        where: { id: existing.id },
        data: this.data(body),
      });
    return this.prisma.companyShowcase.create({ data: this.data(body) });
  }
  async update(id: string, body: ShowcaseBody) {
    try {
      return await this.prisma.companyShowcase.update({
        where: { id },
        data: this.data(body),
      });
    } catch {
      throw new NotFoundException('Company showcase not found');
    }
  }
  async remove(id: string) {
    try {
      return await this.prisma.companyShowcase.delete({ where: { id } });
    } catch {
      throw new NotFoundException('Company showcase not found');
    }
  }
}
