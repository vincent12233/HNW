import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { timingSafeEqual } from 'node:crypto';
import type { Request } from 'express';

function isPrivateOrLoopbackAddress(value?: string): boolean {
  const address = (value ?? '')
    .trim()
    .toLowerCase()
    .split('%')[0]
    .replace(/^::ffff:/, '');
  if (!address) return false;
  if (address === '::1' || address === 'localhost') return true;
  if (/^f[cd][0-9a-f]{2}:/i.test(address)) return true;
  if (/^fe[89ab][0-9a-f]:/i.test(address)) return true;

  const octets = address.split('.').map(Number);
  if (
    octets.length !== 4 ||
    octets.some((octet) => !Number.isInteger(octet) || octet < 0 || octet > 255)
  ) {
    return false;
  }
  return (
    octets[0] === 127 ||
    octets[0] === 10 ||
    (octets[0] === 192 && octets[1] === 168) ||
    (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31)
  );
}

function bearerMatches(request: Request, expected: string): boolean {
  const authorization = request.header('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return false;
  const supplied = authorization.slice('Bearer '.length);
  const expectedBytes = Buffer.from(expected);
  const suppliedBytes = Buffer.from(supplied);
  return (
    expectedBytes.length === suppliedBytes.length &&
    timingSafeEqual(expectedBytes, suppliedBytes)
  );
}

@Injectable()
export class MetricsAccessGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    if (process.env.NODE_ENV !== 'production') return true;

    const request = context.switchToHttp().getRequest<Request>();
    const token = process.env.METRICS_BEARER_TOKEN?.trim() ?? '';
    if (token && bearerMatches(request, token)) return true;
    if (
      isPrivateOrLoopbackAddress(request.ip ?? request.socket.remoteAddress)
    ) {
      return true;
    }

    throw new ForbiddenException('Metrics access is restricted');
  }
}
