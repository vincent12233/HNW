import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { RestoreAppContentDto } from './upsert-app-content.dto';

describe('RestoreAppContentDto', () => {
  it('accepts a revision and ISO timestamp', async () => {
    const errors = await validate(plainToInstance(RestoreAppContentDto, {
      revisionId: 'audit-1',
      expectedUpdatedAt: '2026-09-23T12:00:00.000Z',
    }));
    expect(errors).toHaveLength(0);
  });

  it('rejects missing or malformed restore coordinates', async () => {
    const errors = await validate(plainToInstance(RestoreAppContentDto, {
      revisionId: '', expectedUpdatedAt: 'yesterday',
    }));
    expect(errors.map((error) => error.property).sort()).toEqual(['expectedUpdatedAt', 'revisionId']);
  });
});
