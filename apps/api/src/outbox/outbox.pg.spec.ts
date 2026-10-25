import { readFileSync } from 'node:fs';
import { join } from 'node:path';

describe('Transactional outbox migration contract', () => {
  const migration = readFileSync(
    join(
      process.cwd(),
      'prisma/migrations/20261025230000_transactional_outbox/migration.sql',
    ),
    'utf8',
  );

  it('creates unique event ids and bounded lease indexes', () => {
    expect(migration).toContain('outbox_events_eventId_key');
    expect(migration).toContain(
      'outbox_events_status_availableAt_createdAt_idx',
    );
    expect(migration).toContain('notifications_outboxEventId_key');
  });
});
