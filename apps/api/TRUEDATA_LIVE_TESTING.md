# TrueData live validation

Do not commit real TrueData credentials. Keep them only in the local runtime environment or your deployment secret manager.

## 1. Install locked dependencies

From `apps/api`:

```powershell
npm ci
```

`truedata-nodejs` is already pinned to version `1.2.0` in `package.json` and `package-lock.json`, so no separate SDK install command is required.

## 2. Configure the runtime environment

Start from `.env.truedata.example` and set the real credentials locally:

```text
MARKET_DATA_STREAMING_ENABLED=true
MARKET_DATA_STREAMING_PROVIDER=TRUEDATA
TRUEDATA_USER=<real username>
TRUEDATA_PASSWORD=<real password>
TRUEDATA_PORT=8082
TRUEDATA_BIDASK=true
TRUEDATA_HEARTBEAT=true
TRUEDATA_REPLAY=false
TRUEDATA_URL=push
```

## 3. Run the preflight

```powershell
npm run truedata:preflight
```

The command validates the streaming flags, required credentials, numeric/boolean settings, installed SDK version, and the SDK exports used by the backend. It never prints the username or password and does not open a live TrueData connection.

## 4. Start the API

```powershell
npm run start:dev
```

Initial streaming startup is fail-fast. If credentials, SDK loading, subscriptions, or provider configuration are invalid, NestJS should fail with the specific TrueData error instead of silently entering a reconnect loop.

## 5. Verify health

```powershell
Invoke-RestMethod http://localhost:3000/market-data/health
```

For a working live stream, verify:

```text
streaming.enabled = true
streaming.provider = TRUEDATA
streaming.connected = true
streaming.subscriptionCount > 0
streaming.providerSymbolCount > 0
streaming.lastConnectionError = null
lastSource = TRUEDATA
lastTickAt is recent
```

Then verify the snapshot:

```powershell
Invoke-RestMethod http://localhost:3000/market-data
```

Finally launch Flutter and perform the device market smoke test in `apps/client/DEVICE_TESTING.md`.
