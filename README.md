# HNW Trading Platform

面向印度手机号客户注册的交易平台：客户 App、五个分离的运营后台、API 后端。客服通过客户端内 SaleSmartly 原生 SDK 接入。

**正式环境按服务器部署**（Node + PostgreSQL + Nginx），见 `docs/生产部署说明.md`。仓库同时提供隔离的本机 Docker Compose 环境，专用于 E2E 和后台联调。

## 项目组成

| 模块 | 路径 | 说明 |
| --- | --- | --- |
| API 后端 | `apps/api` | 注册、KYC、账户资金、交易、提现、客服、后台管理接口 |
| 超级管理员后台 | `apps/admin` | 平台治理与员工管理，端口 `3002` |
| 管理员后台 | `apps/admin` | 客户、KYC、业务员管理，端口 `3004` |
| 财务后台 | `apps/admin` | 入金、提现、资金流水，端口 `3005` |
| 业务员后台 | `apps/admin` | 自有客户与业务数据，端口 `3006` |
| 专用运营员后台 | `apps/admin` | 超级管理员固定邀请码客户，端口 `3007` |
| 客户 App | `apps/client` | Flutter 客户端，界面英文 |
| 数据库 | PostgreSQL 17.x | 部署在服务器（或本机原生 Postgres 联调） |

## 核心规则

- 客户注册只需要印度手机号、登录密码、邀请码。
- 客户注册不使用邮箱，不使用短信验证码。
- 后台员工使用员工编号和密码登录，不使用邮箱体系。
- 客户注册成功后，系统自动生成内部客户编号，客户 App 不展示。
- 注册后进入 KYC，可上传 Aadhaar 或 PAN，业务员后台审核。
- 客户入金不在 App 内提交申请，点击 Deposit / Contact Support 后进入在线客服，由财务后台手动上分。
- 客户提现在 App 内提交申请，系统生成提现订单号，客户记录和后台都可查看。
- 超级管理员、管理员、财务可以查看其授权范围内的客户；业务员只能查看自己的客户。
- 专用运营员只能查看使用超级管理员固定邀请码注册的客户。
- 业务员可查看自己客户的入金、提现、订单、成交记录，但不能审核提现。
- 后台统一中文，客户 App 统一英文。

## 生产部署

```text
docs/生产部署说明.md
```

服务器上：`npm ci` → 迁移 / seed → `npm run build` → `npm run start:prod`（API 入口为 `dist/main.js`），五个后台分别构建并用 Nginx 反代。

## 本机 Docker E2E 联调（推荐）

启动 Docker Desktop 后，在仓库根目录执行：

```powershell
$env:HNW_E2E_DB_PASSWORD="HnwE2E_Local_2026_Strong!"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-docker-stack.ps1
```

该环境使用独立的 `hnw_e2e` 数据库，不连接生产数据。停止环境：

```powershell
docker compose -f .\compose.local-test.yaml down
```

启动脚本会等待数据库、API 就绪检查和五个后台登录页通过健康检查后再报告成功。首次构建可能需要下载依赖；若失败，查看仓库根目录的 `docker-compose-startup.log`。这套 Compose 使用开发模式和本机测试密码，不能直接部署到公网。

## 本机联调（无 Docker）

见 `docs/本地启动与联调.md`：本机安装 PostgreSQL + Node，直接跑 API / admin / Flutter。

项目统一使用 Node.js 24 和 npm；`.nvmrc`、GitHub Actions 与本地验证脚本保持一致。不要生成或提交 pnpm/yarn 锁文件。

```bash
nvm use
node --version
npm --version
```

```powershell
cd apps/api
Copy-Item .env.example .env
npm ci
npm run db:generate
npm run db:migrate
npm run seed
npm run start:dev
```

五个运营后台：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-backends.ps1
```

默认访问：

```text
API: http://localhost:3000
超级管理员: http://localhost:3002/login
管理员: http://localhost:3004/login
财务: http://localhost:3005/login
业务员: http://localhost:3006/login
专用运营员: http://localhost:3007/login
```

Docker E2E API 地址为 `http://localhost:3100`，后台端口仍为 `3002/3004/3005/3006/3007`。

客户 App：

```powershell
cd apps/client
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Android 真机 E2E（需要 USB 调试设备）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-android-e2e.ps1
```

连接多台设备时加 `-DeviceSerial <adb devices 中的设备序列号>`；更改 API 端口时加 `-ApiPort 3200`。脚本先检查本地 API 和数据库，再构建、安装和启动 App。完成此步骤只表示真机测试环境已就绪，业务 E2E 仍需按验收清单逐项执行。

## 默认后台账号

| 角色 | 员工编号 | 密码 |
| --- | --- | --- |
| 超级管理员 | `ADMIN001` | `ADMIN_INITIAL_PASSWORD` 环境变量 |
| 管理员 | `MANAGER001` | `MANAGER_INITIAL_PASSWORD` 环境变量 |
| 财务 | `FINANCE001` | `FINANCE_INITIAL_PASSWORD` 环境变量 |
| 业务员 | `BUSINESS001` | `BUSINESS_INITIAL_PASSWORD` 环境变量 |
| 专用运营员 | `SUPPORT001` | `SUPPORT_INITIAL_PASSWORD` 环境变量 |

原生部署和正式环境不提供默认密码：首次初始化前必须在 API 环境变量中设置各角色强密码。本机 Docker 环境有隔离测试专用的默认值，见 `compose.local-test.yaml` 中的 `HNW_E2E_*_PASSWORD`；可在首次启动前覆盖。种子脚本不会重置已有账号密码，修改环境变量也不会更改已有数据库中的密码。

## 免账号行情与新闻

- 默认行情来自 Yahoo 公开快照，每 10 秒轮询活跃、持仓和挂单股票，并通过 WebSocket 推送到 App。
- 该模式无需账号或 API Key，属于近实时/可能延迟行情，不是 NSE/BSE 授权的交易级实时数据。
- 新闻默认聚合 NSE 公司公告、SEBI 更新和印度股票市场新闻，每 60 秒更新并自动去重。
- 如需替换新闻源，可在 API 环境中设置逗号分隔的 `MARKET_NEWS_RSS_URLS`。

## 一键验收

macOS / Linux：

```bash
./scripts/verify-all.sh
```

如果设置了 `DATABASE_URL`，脚本会先执行 Prisma 迁移，并运行 PostgreSQL 集成测试。建议在 OrbStack PostgreSQL 启动后使用：

```bash
export DATABASE_URL='postgresql://hnw_test:<password>@127.0.0.1:55432/hnw_e2e?schema=public'
export HNW_VERIFY_PG=1
./scripts/verify-all.sh
```

Windows：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1
```

快速检查，不跑业务冒烟：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -SkipVerification
```

## 文档

- `docs/生产部署说明.md`（服务器上线主路径）
- `docs/本地启动与联调.md`（本机无 Docker 联调）
- `docs/运营流程说明.md`
- `docs/客户APP发布配置.md`
- `docs/交付验收清单.md`
- `docs/上线准备与验收.md`（发布门槛与待补验证）
- `docs/项目交付总览.md`
