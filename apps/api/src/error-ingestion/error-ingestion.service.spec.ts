import { ErrorIngestionService } from './error-ingestion.service';

describe('ErrorIngestionService', () => {
  it('redacts client reports again before accepting them', () => {
    const service = new ErrorIngestionService();
    const result = service.accept({
      event: 'client_error',
      operation: 'POST /login?token=secret',
      error: 'StateError',
      fingerprint: 'abc123',
      message: 'person@example.com password=top-secret',
      stack: 'C:\\Users\\private-user\\app.dart:1',
      timestamp: '2026-09-27T00:00:00.000Z',
    });
    expect(result).toEqual({ accepted: true, fingerprint: 'abc123' });
  });
});
