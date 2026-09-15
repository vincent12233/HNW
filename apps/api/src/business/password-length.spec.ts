import { validate } from 'class-validator';
import { CreateTeamStaffDto, TeamPasswordDto } from './team.dto';
import { LoginDto } from '../auth/dto/login.dto';

describe('Backend password length', () => {
  it.each([5, 6, 11, 12, 72, 73])(
    'validates creation and reset at length %i',
    async (length) => {
      const password = 'a'.repeat(length);
      const create = Object.assign(new CreateTeamStaffDto(), {
        employeeNo: 'TEST01',
        fullName: 'Test Staff',
        password,
      });
      const reset = Object.assign(new TeamPasswordDto(), {
        newPassword: password,
      });
      for (const dto of [create, reset]) {
        expect((await validate(dto)).length === 0).toBe(
          length >= 12 && length <= 72,
        );
      }
    },
  );
  it('accepts six-character staff login and rejects five characters', async () => {
    // Login floor stays at 6 so legacy accounts can still authenticate;
    // create/reset require ≥12.
    const dto = Object.assign(new LoginDto(), {
      employeeNo: 'TEST01',
      password: 'abc123',
    });
    expect(await validate(dto)).toHaveLength(0);
    dto.password = 'abc12';
    expect((await validate(dto)).length).toBeGreaterThan(0);
  });
});
