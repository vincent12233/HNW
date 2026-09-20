import { readFileSync } from 'fs';
import { join } from 'path';

describe('VIP administration authorization surface', () => {
  const admin = readFileSync(
    join(__dirname, 'vip-admin.controller.ts'),
    'utf8',
  );
  const team = readFileSync(join(__dirname, 'vip-team.controller.ts'), 'utf8');
  const business = readFileSync(
    join(__dirname, 'vip-business.controller.ts'),
    'utf8',
  );

  it('keeps configuration writes on ADMIN only', () => {
    expect(admin).toMatch(/@Roles\(UserRole\.ADMIN\)/);
    expect(admin).toMatch(/Patch\('vip-tiers\/:tierCode'\)/);
    expect(admin).not.toMatch(/UserRole\.FINANCE/);
    expect(admin).not.toMatch(/UserRole\.SUPPORT/);
    expect(admin).not.toMatch(/UserRole\.CLIENT/);
  });

  it('keeps manager VIP routes read-only', () => {
    expect(team).toMatch(/@Roles\(UserRole\.MANAGER\)/);
    expect(team).not.toMatch(/@Patch/);
    expect(team).not.toMatch(/vip-tiers/);
  });

  it('keeps business VIP writes on BUSINESS and requires a reason DTO', () => {
    expect(business).toMatch(/@Roles\(UserRole\.BUSINESS\)/);
    expect(business).toMatch(/Patch\(':userId\/tier'\)/);
    expect(business).not.toMatch(/UserRole\.SUPPORT/);
    expect(business).not.toMatch(/UserRole\.FINANCE/);
    expect(business).toMatch(/AdjustVipClientTierDto/);
  });
});
