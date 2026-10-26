import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize } from 'node:path';

const root = normalize(join(import.meta.dirname, '../../apps/client/build/web'));
const types = new Map([
  ['.css', 'text/css'],
  ['.html', 'text/html'],
  ['.ico', 'image/x-icon'],
  ['.js', 'text/javascript'],
  ['.json', 'application/json'],
  ['.png', 'image/png'],
  ['.wasm', 'application/wasm'],
]);

createServer((request, response) => {
  const pathname = new URL(request.url ?? '/', 'http://127.0.0.1').pathname;
  const candidate = normalize(join(root, pathname));
  const safeFile = candidate.startsWith(root) && existsSync(candidate) && statSync(candidate).isFile()
    ? candidate
    : join(root, 'index.html');
  response.setHeader('Content-Type', types.get(extname(safeFile)) ?? 'application/octet-stream');
  response.setHeader('Cache-Control', 'no-store');
  createReadStream(safeFile).pipe(response);
}).listen(4173, '127.0.0.1');
