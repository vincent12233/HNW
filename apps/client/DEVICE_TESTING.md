# Flutter device testing

The client reads `API_BASE_URL` from `--dart-define`.

## Defaults

- Web: `http://localhost:3000`
- iOS simulator: `http://localhost:3000`
- Android emulator: `http://10.0.2.2:3000`

## Verify the API before launching Flutter

The API already exposes a market-data health endpoint. Check it from the development PC first:

```powershell
Invoke-RestMethod http://localhost:3000/market-data/health
```

Then verify that a snapshot is available:

```powershell
Invoke-RestMethod http://localhost:3000/market-data
```

For a physical device, also verify the LAN address from another device on the same network:

```text
http://<PC-LAN-IP>:3000/market-data/health
```

Do not start Flutter device debugging until the device can reach this URL.

## Android physical device

Put the phone and development PC on the same LAN, make sure the API listens on an address reachable from the LAN, then run:

```powershell
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://<PC-LAN-IP>:3000
```

Example:

```powershell
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://192.168.1.20:3000
```

### Same-Wi-Fi local API

The local Docker test API listens on port `3100`. It defaults to `127.0.0.1`
for safety. To let a physical phone reach it over the same Wi-Fi, bind it to the
PC's Wi-Fi address (the example below uses `192.168.1.88`). Set the bind IP
whenever starting/recreating the API container:

```sh
: "${HNW_E2E_DB_PASSWORD:?Export the local test database password first}"
HNW_E2E_BIND_IP=192.168.1.88 docker compose -f compose.local-test.yaml up -d api
curl --fail http://192.168.1.88:3100/health/ready
```

Keep the phone and PC on the same Wi-Fi, then configure the Android app with
that same address:

```sh
cd apps/client
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://192.168.1.88:3100
```

To build and install a debug APK instead, use the same `API_BASE_URL` value
with these commands:

```sh
cd apps/client
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.88:3100
adb -s <android-device-id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

Make sure the phone remains on the same trusted Wi-Fi as the PC. Release
builds must use a public HTTPS API URL; do not expose the local test API to
untrusted networks.

The Android debug manifest permits cleartext HTTP for local development. Release builds do not get that debug-only cleartext setting. Prefer HTTPS for deployed environments.

## iPhone physical device

Put the iPhone and development machine on the same LAN and run:

```powershell
flutter run -d <iphone-device-id> --dart-define=API_BASE_URL=http://<PC-LAN-IP>:3000
```

The app declares local-network access for development testing. Accept the local-network permission prompt on the device. Prefer an HTTPS API URL for deployed environments.

## Market stream smoke test

After sign-in, keep the Markets screen visible and verify all of the following:

1. Initial prices load from `/market-data`.
2. Subsequent `market-update` Socket.IO ticks update prices without a manual refresh.
3. Background the app for at least 15 seconds, then return to it; prices should refresh automatically.
4. Toggle Wi-Fi off/on or switch between Wi-Fi and mobile data; the stream should reconnect silently and reconcile from the latest snapshot.
5. No reconnect banner should be shown.

For debugging, watch the Flutter console for `Market websocket connected`, `Market update`, and `Market snapshot refreshed` messages in debug builds.

## Hosted / production API

Use the deployed HTTPS API URL explicitly:

```powershell
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

The same base URL is used by HTTP requests and Socket.IO market streaming, so no separate websocket host is required.
