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

## SaleSmartly 在线客服

充值页「联系客服」与首页侧边悬浮客服共用同一套 SaleSmartly 原生 SDK（Android / iOS）。

配置优先级：

1. 超管后台 **客户端运营配置 → 客服 → SaleSmartly Script URL**（保存时自动同步 English / Hindi）
2. API 环境变量 `SALESMARTLY_SCRIPT_URL`（CMS 为空时作为回退）
3. APP 构建参数 `--dart-define=SALESMARTLY_SCRIPT_URL=...`（仅当 CMS 与 API 环境变量都未配置时）

后台填写示例：从 SaleSmartly 工作台复制聊天组件代码，可粘贴完整
`<script src="https://plugin-code.salesmartly.com/js/project_....js"></script>`
或只粘贴 `src` 中的 URL；保存时会自动提取 URL，并同步 English / Hindi。

当前项目默认 Script URL：

`https://plugin-code.salesmartly.com/js/project_829333_860505_1789464929.js`

Android 正式包也可同时写入构建参数作备份：

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://你的API域名 `
  --dart-define=SALESMARTLY_SCRIPT_URL=https://你的SaleSmartly脚本地址
```

Web 构建不会打开原生 SaleSmartly SDK；请用 Android / iOS 包验证客服入口。

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
