#!/usr/bin/env node
/**
 * Local/staging virus-scan stub that speaks the HNW KYC contract:
 *   POST application/octet-stream → body text "CLEAN"
 *
 * Optional auth: set VIRUS_SCAN_BEARER_TOKEN; clients must send
 *   Authorization: Bearer <token>
 *
 * Do NOT expose this stub on the public internet for production.
 *
 * Usage:
 *   node scripts/virus-scan-stub.mjs
 *   VIRUS_SCAN_BEARER_TOKEN=secret PORT=8089 node scripts/virus-scan-stub.mjs
 */
import { createServer } from 'node:http';

const port = Number(process.env.PORT || 8089);
const expectedBearer = process.env.VIRUS_SCAN_BEARER_TOKEN?.trim() || '';

const server = createServer(async (req, res) => {
  if (req.method !== 'POST') {
    res.writeHead(405, { 'content-type': 'text/plain' });
    res.end('METHOD_NOT_ALLOWED');
    return;
  }
  if (expectedBearer) {
    const auth = req.headers.authorization || '';
    if (auth !== `Bearer ${expectedBearer}`) {
      res.writeHead(401, { 'content-type': 'text/plain' });
      res.end('UNAUTHORIZED');
      return;
    }
  }
  // Drain body; stub always reports CLEAN.
  for await (const _chunk of req) {
    // ignore
  }
  res.writeHead(200, { 'content-type': 'text/plain' });
  res.end('CLEAN');
});

server.listen(port, '127.0.0.1', () => {
  console.log(
    `Virus-scan stub listening on http://127.0.0.1:${port} (local only)`,
  );
});
