# HNW 客户 App（Flutter）

印度手机号客户端：注册 / KYC / 交易 / 提现 / 在线客服。界面英文。

## 本地运行

```powershell
cd apps/client
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

真机联调请把 `localhost` 换成电脑局域网 IP。允许本机 HTTP 时再加 `--dart-define=ALLOW_INSECURE_API=true`（仅开发）。

## 正式构建

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

签名与商店配置见 `docs/客户APP发布配置.md`。服务器部署总览见 `docs/生产部署说明.md`。
