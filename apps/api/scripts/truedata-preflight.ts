function requireEnv(name: string) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function booleanEnv(name: string, fallback: boolean) {
  const value = process.env[name]?.trim().toLowerCase();
  if (!value) return fallback;
  if (value === 'true' || value === '1') return true;
  if (value === 'false' || value === '0') return false;
  throw new Error(`${name} must be true/false or 1/0`);
}

function positiveIntegerEnv(name: string, fallback: number) {
  const raw = process.env[name]?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return value;
}

function loadSdk() {
  try {
    const sdk = require('truedata-nodejs');
    const pkg = require('truedata-nodejs/package.json');
    return { sdk, version: String(pkg.version ?? 'unknown') };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(
      `truedata-nodejs is not installed or cannot be loaded: ${message}`,
    );
  }
}

function main() {
  const enabled = booleanEnv('MARKET_DATA_STREAMING_ENABLED', false);
  const provider =
    process.env.MARKET_DATA_STREAMING_PROVIDER?.trim().toUpperCase() ?? 'NONE';

  if (!enabled) {
    throw new Error('MARKET_DATA_STREAMING_ENABLED must be true');
  }
  if (provider !== 'TRUEDATA') {
    throw new Error('MARKET_DATA_STREAMING_PROVIDER must be TRUEDATA');
  }

  const user = requireEnv('TRUEDATA_USER');
  const password = requireEnv('TRUEDATA_PASSWORD');
  const port = positiveIntegerEnv('TRUEDATA_PORT', 8082);
  const bidask = booleanEnv('TRUEDATA_BIDASK', true);
  const heartbeat = booleanEnv('TRUEDATA_HEARTBEAT', true);
  const replay = booleanEnv('TRUEDATA_REPLAY', false);
  const url = process.env.TRUEDATA_URL?.trim() || 'push';

  const { sdk, version } = loadSdk();
  const requiredExports = [
    'rtConnect',
    'rtDisconnect',
    'rtSubscribe',
    'rtFeed',
    'isSocketConnected',
  ];
  const missingExports = requiredExports.filter(
    (name) => typeof sdk[name] === 'undefined',
  );
  if (missingExports.length > 0) {
    throw new Error(
      `truedata-nodejs ${version} is missing required exports: ${missingExports.join(', ')}`,
    );
  }

  console.log('TrueData preflight passed');
  console.log(`SDK version: ${version}`);
  console.log(`User configured: ${user.length > 0 ? 'yes' : 'no'}`);
  console.log(`Password configured: ${password.length > 0 ? 'yes' : 'no'}`);
  console.log(`Port: ${port}`);
  console.log(`Bid/ask: ${bidask}`);
  console.log(`Heartbeat: ${heartbeat}`);
  console.log(`Replay: ${replay}`);
  console.log(`URL: ${url}`);
}

try {
  main();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`TrueData preflight failed: ${message}`);
  process.exitCode = 1;
}
