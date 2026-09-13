import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CompanyShowcaseService {
  constructor(private readonly prisma: PrismaService) {}
  listPublic() { return this.prisma.companyShowcase.findMany({ where: { status: 'ACTIVE' }, orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }], take: 1 }); }
  listAll() { return this.prisma.companyShowcase.findMany({ orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }] }); }
  private data(body: any) {
    const name = String(body?.name ?? '').trim();
    const tagline = String(body?.tagline ?? '').trim();
    const description = String(body?.description ?? '').trim();
    if (!name || !tagline || !description) throw new BadRequestException('Name, tagline and description are required');
    return { name, tagline, description, logoUrl: body?.logoUrl?.trim() || null, websiteUrl: body?.websiteUrl?.trim() || null, sector: body?.sector?.trim() || null, status: body?.status === 'INACTIVE' ? 'INACTIVE' : 'ACTIVE', sortOrder: Number.isFinite(Number(body?.sortOrder)) ? Number(body.sortOrder) : 0 };
  }
  async create(body: any) { const existing = await this.prisma.companyShowcase.findFirst({ orderBy: { createdAt: 'asc' } }); if (existing) return this.prisma.companyShowcase.update({ where: { id: existing.id }, data: this.data(body) }); return this.prisma.companyShowcase.create({ data: this.data(body) }); }
  async update(id: string, body: any) { try { return await this.prisma.companyShowcase.update({ where: { id }, data: this.data(body) }); } catch { throw new NotFoundException('Company showcase not found'); } }
  async remove(id: string) { try { return await this.prisma.companyShowcase.delete({ where: { id } }); } catch { throw new NotFoundException('Company showcase not found'); } }
}
