import { HttpException, Logger, UnauthorizedException } from '@nestjs/common';
import { AllExceptionsFilter } from './all-exceptions.filter';

describe('Authentication error response contracts', () => {
  function responseFor(exception: unknown) {
    const json = jest.fn();
    const response = {
      getHeader: () => 'request',
      status: jest.fn().mockReturnValue({ json }),
    };
    const errorLogging = jest
      .spyOn(Logger.prototype, 'error')
      .mockImplementation(() => undefined);
    const warningLogging = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation(() => undefined);
    try {
      new AllExceptionsFilter().catch(exception, {
        switchToHttp: () => ({
          getResponse: () => response,
          getRequest: () => ({ method: 'POST', path: '/auth/login' }),
        }),
      } as any);
    } finally {
      errorLogging.mockRestore();
      warningLogging.mockRestore();
    }
    return json.mock.calls[0][0];
  }
  it('preserves only known authentication challenge fields', () => {
    expect(
      responseFor(
        new UnauthorizedException({
          message: 'Verification required',
          twoFactorRequired: true,
          passwordHash: 'secret',
        }),
      ),
    ).toMatchObject({ statusCode: 401, twoFactorRequired: true });
    expect(
      responseFor(
        new UnauthorizedException({
          twoFactorRequired: true,
          passwordHash: 'secret',
        }),
      ).passwordHash,
    ).toBeUndefined();
    expect(
      responseFor(new UnauthorizedException({ kycToken: 'onboarding' }))
        .kycToken,
    ).toBe('onboarding');
  });
  it('never passes challenge fields through internal errors', () => {
    const result = responseFor(
      new HttpException(
        {
          message: 'private error',
          kycToken: 'secret',
          twoFactorRequired: true,
        },
        500,
      ),
    );
    expect(result.message).toBe('Internal server error');
    expect(result.kycToken).toBeUndefined();
    expect(result.twoFactorRequired).toBeUndefined();
  });

  it('uses warning logs for expected client errors and error logs for server errors', () => {
    const filter = new AllExceptionsFilter();
    const response = {
      getHeader: () => 'request',
      status: jest.fn().mockReturnValue({ json: jest.fn() }),
    };
    const host = {
      switchToHttp: () => ({
        getResponse: () => response,
        getRequest: () => ({ method: 'POST', path: '/auth/login' }),
      }),
    } as any;
    const errorLogging = jest
      .spyOn(Logger.prototype, 'error')
      .mockImplementation(() => undefined);
    const warningLogging = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation(() => undefined);

    try {
      filter.catch(new UnauthorizedException(), host);
      expect(warningLogging).toHaveBeenCalledWith(
        expect.stringContaining('"level":"warn"'),
      );
      expect(errorLogging).not.toHaveBeenCalled();

      filter.catch(new HttpException('private error', 500), host);
      expect(errorLogging).toHaveBeenCalledWith(
        expect.stringContaining('"level":"error"'),
      );
    } finally {
      errorLogging.mockRestore();
      warningLogging.mockRestore();
    }
  });
});
