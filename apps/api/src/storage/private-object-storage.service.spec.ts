import { mkdtemp, rm } from 'fs/promises';
import { tmpdir } from 'os';
import { join } from 'path';
import { PrivateObjectStorageService } from './private-object-storage.service';

describe('Private object storage', () => {
  let directory: string;
  const previous = process.env.PRIVATE_OBJECT_ROOT;
  beforeEach(async () => {
    directory = await mkdtemp(join(tmpdir(), 'kyc-storage-'));
    process.env.PRIVATE_OBJECT_ROOT = directory;
  });
  afterEach(async () => {
    if (previous === undefined) delete process.env.PRIVATE_OBJECT_ROOT;
    else process.env.PRIVATE_OBJECT_ROOT = previous;
    await rm(directory, { recursive: true, force: true });
  });
  it('uses an absolute root without prepending the working directory', async () => {
    const storage = new PrivateObjectStorageService();
    const bytes = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ZkAAAAASUVORK5CYII=',
      'base64',
    );
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
      delete process.env.OBJECT_SIGNING_SECRET;
    }
  });
});
