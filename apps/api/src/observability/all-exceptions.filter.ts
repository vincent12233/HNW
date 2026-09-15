import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
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
    console.error(
      JSON.stringify({
        level: 'error',
        event: 'unhandled_exception',
        requestId,
        method: request.method,
        path: request.path,
        statusCode: status,
        error: exception instanceof Error ? exception.name : 'UnknownError',
        stack: exception instanceof Error ? exception.stack : undefined,
        timestamp: new Date().toISOString(),
      }),
    );
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
