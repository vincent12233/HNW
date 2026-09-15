# HNW Trading Platform

这是一个面向印度手机号客户注册的交易平台项目，包含客户 App、四个分离的运营后台、API 后端和本地数据库编排。客服通过客户端内的 SaleSmartly 原生 SDK 接入，不再运行独立客服后台。

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
| 数据库 | PostgreSQL 17.x | 生产部署在服务器；本地可用 `compose.yaml` 联调 |

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

## 本地启动

先打开 Docker Desktop，然后复制 `.env.docker.example` 为 `.env.docker`，设置 API 初始化所需的角色密码，再在项目根目录执行：

```powershell
docker compose up -d --build
```

API 会在容器启动时自动执行数据库迁移和种子初始化。若只需单独运行 API 数据库迁移：

```powershell
docker compose logs -f api
```

启动五个分离的运营后台（共用同一个 API 和数据库）：

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
cd ..\client
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

项目不提供固定默认密码。首次初始化前必须在 API 环境变量中设置四个不同的强密码。

## 免账号行情与新闻

- 默认行情来自 Yahoo 公开快照，每 10 秒轮询活跃、持仓和挂单股票，并通过 WebSocket 推送到 App。
- 该模式无需账号或 API Key，属于近实时/可能延迟行情，不是 NSE/BSE 授权的交易级实时数据。
- 新闻默认聚合 NSE 公司公告、SEBI 更新和印度股票市场新闻，每 60 秒更新并自动去重。
- 如需替换新闻源，可在 API 环境中设置逗号分隔的 `MARKET_NEWS_RSS_URLS`。

## 一键验收

完整检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1
```

快速检查，不跑业务冒烟：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -SkipVerification
```

验证脚本会检查 API、运营后台和客户 App，并覆盖注册、KYC、SaleSmartly 客服标签、财务上分、交易、提现订单号和角色数据权限。

## 文档

- `docs/本地启动与联调.md`
- `docs/运营流程说明.md`
- `docs/客户APP发布配置.md`
- `docs/交付验收清单.md`
- `docs/生产部署说明.md`
- `docs/项目交付总览.md`
