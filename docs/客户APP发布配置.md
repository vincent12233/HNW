# 客户 APP 发布配置

## API 地址

客户 APP 的接口地址统一通过 `API_BASE_URL` 设置，HTTP 和行情 WebSocket 都会使用同一个地址。

本地 Web 构建示例：

```powershell
flutter build web --dart-define=API_BASE_URL=http://localhost:3000
```

Android 正式包示例：

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://你的API域名
```

## Android 签名

在 `apps/client/android/key.properties` 中配置签名信息。该文件已被 `.gitignore` 忽略，不要提交到仓库。

示例：

```properties
storePassword=你的store密码
keyPassword=你的key密码
keyAlias=你的key别名
storeFile=C:\\keys\\india-trading-release.jks
```

如果没有 `key.properties`，本地 release 构建会临时使用 debug 签名，方便调试；正式发布前必须配置自己的 release keystore。
