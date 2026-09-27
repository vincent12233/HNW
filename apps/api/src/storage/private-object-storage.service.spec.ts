import { mkdtemp, rm } from 'fs/promises';
import { tmpdir } from 'os';
import { join } from 'path';
import { renderPrometheusMetrics } from '../observability/metrics';
import { PrivateObjectStorageService } from './private-object-storage.service';

describe('Private object storage', () => {
  let directory: string;
  const previousRoot = process.env.PRIVATE_OBJECT_ROOT;
  const previousSigningSecret = process.env.OBJECT_SIGNING_SECRET;

  beforeEach(async () => {
    directory = await mkdtemp(join(tmpdir(), 'kyc-storage-'));
    process.env.PRIVATE_OBJECT_ROOT = directory;
    process.env.OBJECT_SIGNING_SECRET =
      'test-object-signing-secret-that-is-unique-32chars';
  });

  afterEach(async () => {
    if (previousRoot === undefined) delete process.env.PRIVATE_OBJECT_ROOT;
    else process.env.PRIVATE_OBJECT_ROOT = previousRoot;
    if (previousSigningSecret === undefined)
      delete process.env.OBJECT_SIGNING_SECRET;
    else process.env.OBJECT_SIGNING_SECRET = previousSigningSecret;
    delete process.env.VIRUS_SCAN_URL;
    delete process.env.VIRUS_SCAN_BEARER_TOKEN;
    jest.restoreAllMocks();
    await rm(directory, { recursive: true, force: true });
  });

  it('uses an absolute root without prepending the working directory', async () => {
    const storage = new PrivateObjectStorageService();
    const bytes = pngBytes();
    const file = await storage.putKyc('test-user', bytes, 'image/png');
    expect(await storage.get(file.key)).toEqual(bytes);
    await storage.remove(file.key);
  });

  it('accepts HEIC image signatures', async () => {
    const storage = new PrivateObjectStorageService();
    const bytes = Buffer.alloc(24);
    bytes.writeUInt32BE(bytes.length, 0);
    bytes.write('ftyp', 4, 'ascii');
    bytes.write('heic', 8, 'ascii');
    const file = await storage.putKyc('test-user', bytes, 'image/heic');
    expect(file.mime).toBe('image/heic');
    await storage.remove(file.key);
  });

  it('rejects traversal including siblings with the same root prefix', async () => {
    const storage = new PrivateObjectStorageService();
    await expect(storage.get('../outside')).rejects.toThrow(
      'Invalid object key',
    );
    await expect(storage.get(directory + '-sibling/file')).rejects.toThrow(
      'Invalid object key',
    );
  });

  it('requires an absolute PRIVATE_OBJECT_ROOT in production', () => {
    const previousEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    process.env.PRIVATE_OBJECT_ROOT = 'relative-objects';
    process.env.OBJECT_SIGNING_SECRET =
      'production-object-signing-secret-32chars!!';
    try {
      expect(() => new PrivateObjectStorageService()).toThrow(
        /absolute filesystem path/,
      );
    } finally {
      process.env.NODE_ENV = previousEnv;
      process.env.PRIVATE_OBJECT_ROOT = directory;
      process.env.OBJECT_SIGNING_SECRET =
        'test-object-signing-secret-that-is-unique-32chars';
    }
  });

  it('records a clean malware scan and forwards bearer authorization', async () => {
    process.env.VIRUS_SCAN_URL = 'https://scanner.example.test/scan';
    process.env.VIRUS_SCAN_BEARER_TOKEN = 'scanner-token';
    const fetchMock = jest
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response('CLEAN', { status: 200 }));
    const storage = new PrivateObjectStorageService();
    const file = await storage.putKyc('scan-user', pngBytes(), 'image/png');

    expect(fetchMock).toHaveBeenCalledWith(
      process.env.VIRUS_SCAN_URL,
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          authorization: 'Bearer scanner-token',
        }),
      }),
    );
    expect(renderPrometheusMetrics()).toContain(
      'hnw_operational_counters_total{event="kyc_malware_scan_clean"}',
    );
    await storage.remove(file.key);
  });

  it('rejects files that fail malware inspection', async () => {
    process.env.VIRUS_SCAN_URL = 'https://scanner.example.test/scan';
    jest
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response('INFECTED', { status: 200 }));
    const storage = new PrivateObjectStorageService();

    await expect(
      storage.putKyc('scan-user', pngBytes(), 'image/png'),
    ).rejects.toThrow('File failed malware inspection');
    expect(renderPrometheusMetrics()).toContain(
      'hnw_operational_counters_total{event="kyc_malware_scan_rejected"}',
    );
  });

  it('fails closed when the malware scanner is unavailable', async () => {
    process.env.VIRUS_SCAN_URL = 'https://scanner.example.test/scan';
    jest
      .spyOn(globalThis, 'fetch')
      .mockRejectedValue(new Error('scanner offline'));
    const storage = new PrivateObjectStorageService();

    await expect(
      storage.putKyc('scan-user', pngBytes(), 'image/png'),
    ).rejects.toThrow('Malware inspection service is unavailable');
    expect(renderPrometheusMetrics()).toContain(
      'hnw_operational_counters_total{event="kyc_malware_scan_unavailable"}',
    );
  });
});

function pngBytes() {
  return Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ZkAAAAASUVORK5CYII=',
    'base64',
  );
}
