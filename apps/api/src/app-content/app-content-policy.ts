import { BadRequestException } from '@nestjs/common';
import { AppContentPublicationStatus } from '../generated/prisma/enums';

export const ALLOWED_CONTENT_LOCALES = new Set(['en', 'hi', 'zh']);
export const REQUIRED_LEGAL_CONTENT_KEYS = new Set([
  'privacy.document',
  'terms.document',
  'risk.document',
]);

/** Accept a bare URL or a full <script src="..."> snippet from SaleSmartly. */
export function normalizeSaleSmartlyScriptUrl(raw: string): string {
  const text = String(raw ?? '').trim();
  if (!text) return '';
  const srcMatch = text.match(/src\s*=\s*["']([^"']+)["']/i);
  if (srcMatch?.[1]) return srcMatch[1].trim();
  return text;
}

export function beforePublicationStatus(isActive?: boolean) {
  return isActive === false
    ? AppContentPublicationStatus.DRAFT
    : AppContentPublicationStatus.PUBLISHED;
}

export function parseOptionalContentDate(
  value: string | null | undefined,
  field: string,
) {
  if (value == null || value === '') return null;
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) {
    throw new BadRequestException(`Valid ${field} is required`);
  }
  return parsed;
}

export function validateLegalContentDocument(key: string, body: string) {
  if (!REQUIRED_LEGAL_CONTENT_KEYS.has(key)) return;
  try {
    const value = JSON.parse(body) as {
      effective?: unknown;
      sections?: unknown;
    };
    if (typeof value.effective !== 'string' || !value.effective.trim())
      throw new Error();
    if (!Array.isArray(value.sections) || !value.sections.length)
      throw new Error();
    for (const section of value.sections) {
      if (
        !section ||
        typeof section !== 'object' ||
        typeof (section as Record<string, unknown>).heading !== 'string' ||
        !(section as { heading: string }).heading.trim() ||
        typeof (section as Record<string, unknown>).body !== 'string' ||
        !(section as { body: string }).body.trim()
      )
        throw new Error();
    }
  } catch {
    throw new BadRequestException(
      'Required legal documents need effective and non-empty heading/body sections',
    );
  }
}
