import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const context = host.switchToHttp();
    const response = context.getResponse<Response>();
    const request = context.getRequest<Request>();
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const requestId = response.getHeader('x-request-id')?.toString();
    const raw =
      exception instanceof HttpException ? exception.getResponse() : null;
    const extractedMessage =
      raw && typeof raw === 'object' && 'message' in raw
        ? (raw as { message?: unknown }).message
        : undefined;
    const message =
      status >= 500
        ? 'Internal server error'
        : typeof raw === 'string'
          ? raw
          : Array.isArray(extractedMessage)
            ? extractedMessage.map(String).join(', ')
            : typeof extractedMessage === 'string'
              ? extractedMessage
              : 'Request failed';
    const auditEntry = JSON.stringify({
      level: status >= 500 ? 'error' : 'warn',
      event: 'unhandled_exception',
      requestId,
      method: request.method,
      path: request.path,
      statusCode: status,
      error: exception instanceof Error ? exception.name : 'UnknownError',
      ...(status >= 500 && exception instanceof Error
        ? { stack: exception.stack }
        : {}),
      timestamp: new Date().toISOString(),
    });
    if (status >= 500) {
      this.logger.error(auditEntry);
    } else {
      this.logger.warn(auditEntry);
    }
    const authentication =
      status === Number(HttpStatus.UNAUTHORIZED) &&
      raw &&
      typeof raw === 'object'
        ? (raw as Record<string, unknown>)
        : {};
    response.status(status).json({
      statusCode: status,
      message,
      requestId,
      timestamp: new Date().toISOString(),
      ...(authentication.twoFactorRequired === true
        ? { twoFactorRequired: true }
        : {}),
      ...(typeof authentication.kycToken === 'string'
        ? { kycToken: authentication.kycToken }
        : {}),
    });
  }
}
