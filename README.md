# HNW Trading Platform

面向印度手机号客户注册的交易平台：客户 App、五个分离的运营后台、API 后端。客服通过客户端内 SaleSmartly 原生 SDK 接入。

**正式环境按服务器部署**（Node + PostgreSQL + Nginx），见 `docs/生产部署说明.md`。不再提供本机 Docker / compose 编排。

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

## 本机联调（无 Docker）

见 `docs/本地启动与联调.md`：本机安装 PostgreSQL + Node，直接跑 API / admin / Flutter。

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

客户 App：

```powershell
cd apps/client
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## 默认后台账号

| 角色 | 员工编号 | 密码 |
| --- | --- | --- |
| 超级管理员 | `ADMIN001` | `ADMIN_INITIAL_PASSWORD` 环境变量 |
| 管理员 | `MANAGER001` | `MANAGER_INITIAL_PASSWORD` 环境变量 |
| 财务 | `FINANCE001` | `FINANCE_INITIAL_PASSWORD` 环境变量 |
| 业务员 | `BUSINESS001` | `BUSINESS_INITIAL_PASSWORD` 环境变量 |
| 专用运营员 | `SUPPORT001` | `SUPPORT_INITIAL_PASSWORD` 环境变量 |

项目不提供固定默认密码。首次初始化前必须在 API 环境变量中设置各角色强密码。

## 免账号行情与新闻

- 默认行情来自 Yahoo 公开快照，每 10 秒轮询活跃、持仓和挂单股票，并通过 WebSocket 推送到 App。
- 该模式无需账号或 API Key，属于近实时/可能延迟行情，不是 NSE/BSE 授权的交易级实时数据。
- 新闻默认聚合 NSE 公司公告、SEBI 更新和印度股票市场新闻，每 60 秒更新并自动去重。
- 如需替换新闻源，可在 API 环境中设置逗号分隔的 `MARKET_NEWS_RSS_URLS`。

## 一键验收

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
- `docs/项目交付总览.md`
