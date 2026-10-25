import { Prisma } from '../generated/prisma/client';

export type OutboxEventInput = {
  eventId: string;
  type: string;
  aggregateType: string;
  aggregateId: string;
  aggregateVersion: number;
  schemaVersion?: number;
  occurredAt: Date;
  correlationId?: string;
  payload: Prisma.InputJsonValue;
};

export type NotificationRequestedPayload = {
  userId: string;
  type: string;
  title: string;
  body: string;
  referenceId?: string;
};
