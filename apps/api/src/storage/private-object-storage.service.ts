import {
  BadRequestException,
  Injectable,
  OnModuleInit,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createHmac, randomUUID, timingSafeEqual } from 'crypto';
import { mkdir, readFile, writeFile, unlink } from 'fs/promises';
import { isAbsolute, join, relative, resolve, sep } from 'path';

function resolveObjectSigningSecret() {
  const dedicated = process.env.OBJECT_SIGNING_SECRET?.trim() ?? '';
  if (process.env.NODE_ENV === 'production') {
    if (
      dedicated.length < 32 ||
      /replace|change-me|development/i.test(dedicated) ||
      dedicated === process.env.JWT_SECRET
    ) {
      throw new Error(
        'OBJECT_SIGNING_SECRET must be a unique random value of at least 32 characters',
      );
    }
    return dedicated;
  }
  return dedicated || process.env.JWT_SECRET || 'development-only-change-me';
}

function resolvePrivateObjectRoot() {
  const configured = process.env.PRIVATE_OBJECT_ROOT?.trim() ?? '';
  if (process.env.NODE_ENV === 'production') {
    if (!configured || !isAbsolute(configured)) {
      throw new Error(
        'PRIVATE_OBJECT_ROOT must be an absolute filesystem path in production',
      );
    }
    return configured;
  }
  return resolve(process.cwd(), configured || 'private-objects');
}

@Injectable()
export class PrivateObjectStorageService implements OnModuleInit {
  private readonly root = resolvePrivateObjectRoot();
  private readonly secret = resolveObjectSigningSecret();

  onModuleInit() {
    if (
      process.env.NODE_ENV === 'production' &&
      (!process.env.OBJECT_SIGNING_SECRET ||
        this.secret.length < 32 ||
        this.secret === process.env.JWT_SECRET)
    ) {
      throw new Error(
        'OBJECT_SIGNING_SECRET must be a unique random value of at least 32 characters',
      );
    }
    if (
      process.env.NODE_ENV === 'production' &&
      (!process.env.PRIVATE_OBJECT_ROOT?.trim() || !isAbsolute(this.root))
    ) {
      throw new Error(
        'PRIVATE_OBJECT_ROOT must be an absolute filesystem path in production',
      );
    }
  }

  async putKyc(userId: string, bytes: Buffer, declaredMime?: string) {
    const mime = this.detectMime(bytes);
    const heifFamily = (value?: string | null) =>
      value === 'image/heic' || value === 'image/heif';
    const declaredMatches =
      !declaredMime ||
      declaredMime === mime ||
      (heifFamily(declaredMime) && heifFamily(mime));
    if (!mime || !declaredMatches)
      throw new BadRequestException(
        'File content does not match an allowed PDF or image type',
      );
    await this.scan(bytes);
    const key = `kyc/${userId}/${Date.now()}-${randomUUID()}`;
    const path = this.resolve(key);
    await mkdir(join(this.root, 'kyc', userId), { recursive: true });
    await writeFile(path, bytes, { flag: 'wx' });
    return { key, mime };
  }

  async get(key: string) {
    return readFile(this.resolve(key));
  }
  async remove(key: string) {
    await unlink(this.resolve(key));
  }
  sign(key: string, ttlSeconds = 300) {
    const expires =
      Math.floor(Date.now() / 1000) + Math.min(Math.max(ttlSeconds, 30), 600);
    const signature = createHmac('sha256', this.secret)
      .update(`${key}.${expires}`)
      .digest('hex');
    return { key, expires, signature };
  }
  verify(key: string, expires: number, signature: string) {
    if (!Number.isFinite(expires) || expires < Math.floor(Date.now() / 1000))
      return false;
    const expected = createHmac('sha256', this.secret)
      .update(`${key}.${expires}`)
      .digest('hex');
    return (
      signature.length === expected.length &&
      timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
    );
  }
  private resolve(key: string) {
    const path = resolve(this.root, key);
    const withinRoot = relative(this.root, path);
    if (
      !withinRoot ||
      withinRoot === '..' ||
      withinRoot.startsWith(`..${sep}`) ||
      isAbsolute(withinRoot)
    )
      throw new BadRequestException('Invalid object key');
    return path;
  }
  private detectMime(bytes: Buffer) {
    if (bytes.subarray(0, 4).toString() === '%PDF') return 'application/pdf';
    if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff)
      return 'image/jpeg';
    if (
      bytes
        .subarray(0, 8)
        .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
    )
      return 'image/png';
    if (
      bytes.subarray(0, 4).toString() === 'RIFF' &&
      bytes.subarray(8, 12).toString() === 'WEBP'
    )
      return 'image/webp';
    // HEIC/HEIF files use the ISO Base Media File Format and identify their
    // image family in the `ftyp` major brand at byte offset 8.
    if (bytes.length >= 12 && bytes.subarray(4, 8).toString() === 'ftyp') {
      const brand = bytes.subarray(8, 12).toString();
      if (['heic', 'heix', 'hevc', 'hevx'].includes(brand)) return 'image/heic';
      if (['mif1', 'msf1'].includes(brand)) return 'image/heif';
    }
    return null;
  }
  private async scan(bytes: Buffer) {
    const url = process.env.VIRUS_SCAN_URL;
    if (!url) {
      if (process.env.NODE_ENV === 'production')
        throw new ServiceUnavailableException(
          'Virus scanner is not configured',
        );
      return;
    }
    const headers: Record<string, string> = {
      'content-type': 'application/octet-stream',
    };
    const bearer = process.env.VIRUS_SCAN_BEARER_TOKEN?.trim();
    if (bearer) {
      headers.authorization = `Bearer ${bearer}`;
    }
    let response: Response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers,
        body: new Uint8Array(bytes),
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      throw new ServiceUnavailableException(
        'Malware inspection service is unavailable',
      );
    }
    if (!response.ok)
      throw new ServiceUnavailableException(
        'Malware inspection service is unavailable',
      );
    if ((await response.text()).trim().toUpperCase() !== 'CLEAN')
      throw new BadRequestException('File failed malware inspection');
  }
}
