import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface IstClockParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  weekday: string;
}

const NSE_CM_HOLIDAYS_2026 = new Set([
  '2026-01-15',
  '2026-01-26',
  '2026-02-15',
  '2026-03-03',
  '2026-03-21',
  '2026-03-26',
  '2026-03-31',
  '2026-04-03',
  '2026-04-14',
  '2026-05-01',
  '2026-05-28',
  '2026-06-26',
  '2026-08-15',
  '2026-09-14',
  '2026-10-02',
  '2026-10-20',
  '2026-11-08',
  '2026-11-10',
  '2026-11-24',
  '2026-12-25',
]);

@Injectable()
export class MarketSessionService {
  private readonly timeZone = 'Asia/Kolkata';

  constructor(private readonly config: ConfigService) {}

  isNormalMarketOpen(at = new Date()): boolean {
    const parts = this.istParts(at);
    if (!this.isTradingDayParts(parts)) return false;

    const minuteOfDay = parts.hour * 60 + parts.minute;
    return minuteOfDay >= this.openMinute() && minuteOfDay < this.closeMinute();
  }

  isTradingDay(at = new Date()): boolean {
    return this.isTradingDayParts(this.istParts(at));
  }

  isDayOrderExpired(placedAt: Date, now = new Date()): boolean {
    const placed = this.istParts(placedAt);
    const current = this.istParts(now);
    const placedDate = this.dateKey(placed);
    const currentDate = this.dateKey(current);

    if (currentDate > placedDate) return true;
    if (currentDate < placedDate) return false;

    const minuteOfDay = current.hour * 60 + current.minute;
    return minuteOfDay >= this.closeMinute();
  }

  private isTradingDayParts(parts: IstClockParts): boolean {
    if (parts.weekday === 'Sat' || parts.weekday === 'Sun') return false;
    return !this.holidays().has(this.dateKey(parts));
  }

  private holidays(): Set<string> {
    const holidays = new Set<string>(NSE_CM_HOLIDAYS_2026);
    const raw = this.config.get<string>('MARKET_HOLIDAYS_IST') ?? '';
    for (const value of raw.split(',')) {
      const normalized = value.trim();
      if (/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
        holidays.add(normalized);
      }
    }
    return holidays;
  }

  private openMinute(): number {
    return this.parseMinute(
      this.config.get<string>('MARKET_OPEN_TIME_IST') ?? '09:15',
      9 * 60 + 15,
    );
  }

  private closeMinute(): number {
    return this.parseMinute(
      this.config.get<string>('MARKET_CLOSE_TIME_IST') ?? '15:30',
      15 * 60 + 30,
    );
  }

  private parseMinute(value: string, fallback: number): number {
    const match = /^(\d{2}):(\d{2})$/.exec(value.trim());
    if (!match) return fallback;
    const hour = Number(match[1]);
    const minute = Number(match[2]);
    if (hour > 23 || minute > 59) return fallback;
    return hour * 60 + minute;
  }

  private dateKey(parts: IstClockParts): string {
    return `${parts.year.toString().padStart(4, '0')}-${parts.month
      .toString()
      .padStart(2, '0')}-${parts.day.toString().padStart(2, '0')}`;
  }

  private istParts(at: Date): IstClockParts {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: this.timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      weekday: 'short',
      hourCycle: 'h23',
    });
    const values = Object.fromEntries(
      formatter
        .formatToParts(at)
        .filter((part) => part.type !== 'literal')
        .map((part) => [part.type, part.value]),
    );

    return {
      year: Number(values.year),
      month: Number(values.month),
      day: Number(values.day),
      hour: Number(values.hour),
      minute: Number(values.minute),
      weekday: values.weekday,
    };
  }
}
