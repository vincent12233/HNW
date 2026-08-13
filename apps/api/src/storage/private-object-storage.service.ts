import { BadRequestException, Injectable, OnModuleInit, ServiceUnavailableException } from '@nestjs/common';
import { createHmac, randomUUID, timingSafeEqual } from 'crypto';
import { mkdir, readFile, writeFile } from 'fs/promises';
import { join, normalize } from 'path';

@Injectable()
export class PrivateObjectStorageService implements OnModuleInit {
  private readonly root = join(process.cwd(), process.env.PRIVATE_OBJECT_ROOT || 'private-objects');
  private readonly secret = process.env.OBJECT_SIGNING_SECRET || process.env.JWT_SECRET || 'development-only-change-me';

  onModuleInit() {
    if (process.env.NODE_ENV === 'production' && (!process.env.OBJECT_SIGNING_SECRET || this.secret.length < 32 || this.secret === process.env.JWT_SECRET)) {
      throw new Error('OBJECT_SIGNING_SECRET must be a unique random value of at least 32 characters');
    }
  }

  async putKyc(userId: string, bytes: Buffer, declaredMime?: string) {
    const mime = this.detectMime(bytes);
    if (!mime || (declaredMime && declaredMime !== mime)) throw new BadRequestException('File content does not match an allowed PDF or image type');
    await this.scan(bytes);
    const key = `kyc/${userId}/${Date.now()}-${randomUUID()}`;
    const path = this.resolve(key);
    await mkdir(join(this.root, 'kyc', userId), { recursive: true });
    await writeFile(path, bytes, { flag: 'wx' });
    return { key, mime };
  }

  async get(key: string) { return readFile(this.resolve(key)); }
  sign(key: string, ttlSeconds = 300) {
    const expires = Math.floor(Date.now() / 1000) + Math.min(Math.max(ttlSeconds, 30), 600);
    const signature = createHmac('sha256', this.secret).update(`${key}.${expires}`).digest('hex');
    return { key, expires, signature };
  }
  verify(key: string, expires: number, signature: string) {
    if (!Number.isFinite(expires) || expires < Math.floor(Date.now() / 1000)) return false;
    const expected = createHmac('sha256', this.secret).update(`${key}.${expires}`).digest('hex');
    return signature.length === expected.length && timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
  }
  private resolve(key: string) {
    const path = normalize(join(this.root, key));
    if (!path.startsWith(normalize(this.root))) throw new BadRequestException('Invalid object key');
    return path;
  }
  private detectMime(bytes: Buffer) {
    if (bytes.subarray(0, 4).toString() === '%PDF') return 'application/pdf';
    if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
    if (bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) return 'image/png';
    if (bytes.subarray(0, 4).toString() === 'RIFF' && bytes.subarray(8, 12).toString() === 'WEBP') return 'image/webp';
    return null;
  }
  private async scan(bytes: Buffer) {
    const url = process.env.VIRUS_SCAN_URL;
    if (!url) {
      if (process.env.NODE_ENV === 'production') throw new ServiceUnavailableException('Virus scanner is not configured');
      return;
    }
    const response = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/octet-stream' }, body: new Uint8Array(bytes) });
    if (!response.ok || (await response.text()).trim().toUpperCase() !== 'CLEAN') throw new BadRequestException('File failed malware inspection');
  }
}
