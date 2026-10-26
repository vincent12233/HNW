# HNW Trading Platform

面向印度市场的交易平台，由 Flutter 客户端、NestJS API、Next.js 运营后台和 PostgreSQL 数据库组成。后台提供五个按角色隔离的入口；客服通过客户端内 SaleSmartly 原生 SDK 接入。

**生产部署推荐使用 Coolify + `compose.production.yaml`。** 操作手册见 [`docs/小白部署与运维手册.md`](docs/小白部署与运维手册.md)；原生服务器部署见 [`docs/生产部署说明.md`](docs/生产部署说明.md)。本地可使用 Windows Docker Desktop、macOS OrbStack 或原生 PostgreSQL 进行开发和隔离联调。

## 技术栈

| 层 | 技术 | 位置 |
| --- | --- | --- |
| 客户端 | Flutter / Dart | `apps/client` |
| API | NestJS / Node.js 24 / Prisma 7 | `apps/api` |
| 运营后台 | Next.js / React / TypeScript / Ant Design | `apps/admin` |
| 数据库 | PostgreSQL 17 | `apps/api/prisma` |
| 共享限流 | Redis 7 | API 配置及 Compose 部署 |
| 部署 | Docker Compose / Coolify | `compose.production.yaml` |

依赖管理使用 npm 和 `package-lock.json`；Flutter 使用 `pubspec.lock`。Node.js 版本以仓库根目录的 `.nvmrc` 为准。

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

五个后台入口共用一个 Admin 应用代码库和 API，但分别构建为 `ADMIN`、`MANAGER`、`FINANCE`、`BUSINESS`、`SUPPORT` 角色。端口用于本地开发；生产环境应为各入口配置独立域名和匹配的角色构建，不能依赖端口识别权限。

## 核心规则

- 客户注册只需要印度手机号、登录密码、邀请码。
- 客户注册不使用邮箱，不使用短信验证码。
- 后台员工使用员工编号和密码登录，不使用邮箱体系；首次登录必须扫码绑定 Google Authenticator，后续登录同时输入 6 位动态码。
- 客户注册成功后，系统自动生成内部客户编号，客户 App 不展示。
- 注册后进入 KYC，可上传 Aadhaar 或 PAN，业务员后台审核。
- 客户入金不在 App 内提交申请，点击 Deposit / Contact Support 后进入在线客服，由财务后台手动上分。
- 客户提现在 App 内提交申请，系统生成提现订单号，客户记录和后台都可查看。
- 超级管理员、管理员、财务可以查看其授权范围内的客户；业务员只能查看自己的客户。
- 专用运营员只能查看使用超级管理员固定邀请码注册的客户。
- 业务员可查看自己客户的入金、提现、订单、成交记录，但不能审核提现。
- 后台统一中文，客户 App 支持英文和 Hindi，并在内容缺失时回退英文。

### 安全与隔离

- 后台会话和菜单按角色隔离；API 服务端负责最终授权，前端路由和菜单不作为权限边界。
- 后台首次登录必须完成 Google Authenticator 绑定，后续登录使用动态码；恢复码仅在生成时显示一次。
- 验证器重置遵循管理层级权限，会撤销目标员工的现有会话，并要求其重新绑定。
- 生产配置必须使用独立强密钥、HTTPS、明确的 CORS 来源、Redis 限流和私有文件存储；生产环境不应使用开发行情或本地扫描 stub。
- 客户端交易规则、注册登录流程和存款方式与后台 UI/UX、员工安全功能分开管理；界面优化不代表这些业务规则已改变。

### 后台验证器与重置权限

- 首次绑定通过密码校验后的 10 分钟短时挑战完成；绑定成功前不签发后台会话。
- 绑定成功后只显示一次恢复码，后台不会保存可直接读取的恢复码明文。
- 超级管理员只能重置管理员的验证器；管理员只能重置自己创建的业务员验证器。
- 重置会撤销目标员工的现有会话，并要求下次登录重新扫码绑定；不会修改密码、角色、客户归属或业务权限。
- 财务、专用运营等其他角色不能通过团队管理接口重置员工验证器。
- 该安全流程仅适用于后台员工，不改变客户手机号注册、客户登录、交易逻辑或存款方式。

## 生产部署

```text
docs/生产部署说明.md
```

推荐在 Coolify 中导入 `compose.production.yaml`，由面板完成构建、HTTPS、日志和版本回滚；生产变量从 `.env.production.example` 复制后逐项替换。原生服务器路径仍保留在 `docs/生产部署说明.md`。

生产发布通过手动 GitHub Actions 工作流触发：必须从 `main` 指定已验证的完整提交 SHA，先完成部署配置验证，再经 `production` 环境授权调用 Coolify，并执行部署后端点冒烟检查。具体发布门槛和环境变量以部署手册及工作流为准。仓库不提供可直接用于生产的默认凭据。

## Windows Docker Desktop E2E 联调

Docker Desktop 使用 WSL 2 Linux 容器引擎。启动 Docker Desktop 后，在 PowerShell 中执行：

```powershell
.\scripts\start-docker-desktop-stack.ps1
```

脚本会自动等待 Docker 引擎、验证 Compose 配置、构建镜像，并等待全部服务健康。只需复用现有镜像时可传入 `-SkipBuild`；调整等待时间可使用 `-WaitTimeoutSeconds 900`。
## macOS OrbStack E2E 联调（推荐）

启动 OrbStack 后，在仓库根目录执行：

```bash
./scripts/start-orbstack-stack.sh
```

首次使用可通过 `HNW_E2E_DB_PASSWORD` 覆盖本机测试数据库密码。该密码仅在 PostgreSQL 数据卷首次创建时生效；已有数据卷必须继续使用初始化时的密码，修改环境变量不会同步修改数据库密码。若确认可以删除全部本机测试数据，可运行 `docker compose -f compose.local-test.yaml down -v` 删除数据卷，再使用新密码重新启动。OrbStack 的容器引擎使用标准 `docker compose` 命令，脚本会校验当前 Docker context 为 `orbstack`。

该环境使用独立的 `hnw_e2e` 数据库，不连接生产数据。停止环境：

```bash
docker compose -f compose.local-test.yaml down
```

启动脚本会等待数据库、API 就绪检查和五个后台登录页通过健康检查后再报告成功。首次构建可能需要下载依赖；若失败，运行 `docker compose -f compose.local-test.yaml logs --tail 120` 查看日志。这套 Compose 使用开发模式和本机测试密码，不能直接部署到公网。

## 本机联调（无容器）

见 `docs/本地启动与联调.md`：本机安装 PostgreSQL + Node，直接跑 API / admin / Flutter。

项目统一使用 Node.js 24 和 npm；`.nvmrc`、GitHub Actions 与本地验证脚本保持一致。不要生成或提交 pnpm/yarn 锁文件。
后台测试所用的 Next.js 至少要求 Node.js `20.19.0`；本仓库以 `.nvmrc` 中的 Node.js 24 为准。

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

OrbStack E2E API 地址为 `http://localhost:3100`，后台端口仍为 `3002/3004/3005/3006/3007`。

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

原生部署和正式环境不提供默认密码：首次初始化前必须在 API 环境变量中设置各角色强密码。本机 OrbStack 环境有隔离测试专用的默认值，见 `compose.local-test.yaml` 中的 `HNW_E2E_*_PASSWORD`；可在首次启动前覆盖。种子脚本不会重置已有账号密码，修改环境变量也不会更改已有数据库中的密码。

## 免账号行情与新闻

- 默认行情来自 Yahoo 公开快照，每 10 秒轮询活跃、持仓和挂单股票，并通过 WebSocket 推送到 App。
- 该模式无需账号或 API Key，属于近实时/可能延迟行情，不是 NSE/BSE 授权的交易级实时数据。
- 新闻默认聚合 NSE 公司公告、SEBI 更新和印度股票市场新闻，每 60 秒更新并自动去重。
- 如需替换新闻源，可在 API 环境中设置逗号分隔的 `MARKET_NEWS_RSS_URLS`。

## 一键验收

验证脚本适用于本地开发/测试环境；使用 `DATABASE_URL` 时必须指向专用、可丢弃的测试数据库，不能指向生产库。完整自动化覆盖由 GitHub Actions 对确切提交执行，包含数据库迁移与升级验证、依赖审计、API/Admin/Flutter 检查、Docker 镜像构建和安全分析。

macOS / Linux：

```bash
./scripts/verify-all.sh
```

本地 OrbStack 验证会为后台构建自动使用 `https://build.invalid` 占位地址，
不会改变 API 联调地址；需要指定真实构建地址时设置 `HNW_BUILD_API_URL`。

如果设置了 `DATABASE_URL`，脚本会先执行 Prisma 迁移，并运行 PostgreSQL 集成测试。建议在 OrbStack PostgreSQL 启动后使用：

```bash
export DATABASE_URL='postgresql://hnw_test:<password>@127.0.0.1:55432/hnw_e2e?schema=public'
export HNW_VERIFY_PG=1
export RATE_LIMIT_REDIS_URL='redis://127.0.0.1:56379'
export HNW_VERIFY_REDIS=1
./scripts/verify-all.sh
```

Windows：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1
```

PowerShell 验证脚本同样会在后台构建阶段使用 `HNW_BUILD_API_URL`；未设置时使用 HTTPS 占位地址。

CI 还会生成与提交 SHA 绑定的 `enterprise-acceptance.json`。该报告把验收明确分为仓库、生产环境和外部机构三层：自动化代码检查通过只代表仓库层完成；KYC 服务商、授权行情、真实交易所/清算、法律合规和真机验收没有真实证据时，系统不会宣称已经生产就绪。生产证据聚合工具见 `scripts/production-acceptance.mjs`。

快速检查，不跑业务冒烟：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -SkipVerification
```

## 文档

完整索引和文档状态见 `docs/README.md`。

- `docs/小白部署与运维手册.md`（Coolify 可视化部署、回滚、备份和日常巡检）
- `docs/生产部署说明.md`（原生服务器上线路径）
- `docs/本地启动与联调.md`（本机无容器联调）
- `docs/运营流程说明.md`
- `docs/客户APP发布配置.md`
- `docs/交付验收清单.md`
- `docs/上线准备与验收.md`（发布门槛与待补验证）
- `docs/项目交付总览.md`
- `docs/STATUS.md`（当前完成项、持续改进队列与验证要求）
- `docs/ai/`（项目架构、长期约束和跨会话交接；事实状态需按文档要求重新核验）

## 当前状态

当前完成项、未完成事项和验证规则统一记录在 [`docs/STATUS.md`](docs/STATUS.md)。近期已合并交付记录：

- [PR #146](https://github.com/vincent12233/HNW/pull/146)：后台员工验证器安全与后台/客户端 UI/UX 升级。
- [PR #147](https://github.com/vincent12233/HNW/pull/147)：Admin/API 依赖更新整理。
- [PR #143](https://github.com/vincent12233/HNW/pull/143)：持久化项目上下文文档。

PR 链接用于追溯改动和审查证据；实际交付以 `main` 当前代码为准，自动化验证结果必须对应具体提交。
