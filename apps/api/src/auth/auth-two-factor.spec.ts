import { AuthService } from './auth.service';
import * as bcrypt from 'bcrypt';

describe('Authentication second-factor enforcement', () => {
  async function fixture() {
    const user = { id: 'client', role: 'CLIENT', status: 'ACTIVE', phone: '9999999999', authVersion: 2, passwordHash: await bcrypt.hash('test-password', 4) };
    const jwt = { signAsync: jest.fn().mockResolvedValue('token'), verifyAsync: jest.fn().mockResolvedValue({ sub: 'client', version: 2, purpose: 'BIOMETRIC_LOGIN' }) };
    const prisma = { user: { findUnique: jest.fn().mockResolvedValue(user), findFirst: jest.fn().mockResolvedValue(user) }, loginAudit: { count: jest.fn().mockResolvedValue(0), create: jest.fn() }, userDevice: { create: jest.fn() } };
    const twoFactor = { status: jest.fn().mockResolvedValue({ enabled: true }), verifyLogin: jest.fn().mockRejectedValue(new Error('Second factor required')) };
    const service = new AuthService({ findByPhone: jest.fn().mockResolvedValue(user) } as any, jwt as any, prisma as any, {} as any, twoFactor as any);
    return { service, jwt, prisma, twoFactor };
  }
  it('does not issue a token or log success before verifying the second factor', async () => {
    const { service, jwt, prisma, twoFactor } = await fixture();
    await expect(service.login({ phone: '9999999999', password: 'test-password', verificationCode: '123456' })).rejects.toThrow('Second factor required');
    expect(twoFactor.verifyLogin).toHaveBeenCalledWith('client', '123456');
    expect(jwt.signAsync).not.toHaveBeenCalled();
    expect(prisma.loginAudit.create).not.toHaveBeenCalled();
  });
  it('does not let biometric quick login bypass an enabled second factor', async () => {
    const { service, jwt } = await fixture();
    await expect(service.biometricLogin('biometric-token')).rejects.toThrow('authenticator code');
    expect(jwt.signAsync).not.toHaveBeenCalled();
  });
  it('does not let Google login bypass an enabled second factor', async () => {
    const { service, jwt } = await fixture();
    jest.spyOn(service as any, 'verifyGoogleToken').mockResolvedValue({ subject: 'google', email: 'test@example.invalid' });
    await expect(service.googleLogin('google-token')).rejects.toThrow('authenticator code');
    expect(jwt.signAsync).not.toHaveBeenCalled();
  });
});
