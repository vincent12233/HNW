# Flutter device testing

The client reads `API_BASE_URL` from `--dart-define`.

## Defaults

- Web: `http://localhost:3000`
- iOS simulator: `http://localhost:3000`
- Android emulator: `http://10.0.2.2:3000`

## Android physical device

Put the phone and development PC on the same LAN, make sure the API listens on an address reachable from the LAN, then run:

```powershell
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://<PC-LAN-IP>:3000
```

Example:

```powershell
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://192.168.1.20:3000
```

The Android debug manifest permits cleartext HTTP for local development. Release builds do not get that debug-only cleartext setting. Prefer HTTPS for deployed environments.

## iPhone physical device

Put the iPhone and development machine on the same LAN and run:

```powershell
flutter run -d <iphone-device-id> --dart-define=API_BASE_URL=http://<PC-LAN-IP>:3000
```

The app declares local-network access for development testing. Accept the local-network permission prompt on the device. Prefer an HTTPS API URL for deployed environments.

## Hosted / production API

Use the deployed HTTPS API URL explicitly:

```powershell
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

The same base URL is used by HTTP requests and Socket.IO market streaming, so no separate websocket host is required.
