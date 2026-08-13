# HNW Trading Platform

这是一个面向印度手机号客户注册的交易平台项目，包含客户 App、API 后端、管理后台、独立客服端和本地数据库编排。

## 项目组成

| 模块 | 路径 | 说明 |
| --- | --- | --- |
| API 后端 | `apps/api` | 注册、KYC、账户资金、交易、提现、客服、后台管理接口 |
| 管理后台 | `apps/admin` | 管理员、财务、客服、业务员统一后台，界面中文 |
| 客户 App | `apps/client` | Flutter 客户端，界面英文 |
| 独立客服端 | `apps/support` | 独立在线客服工作台，界面中文 |
| 数据库 | `compose.yaml` | 本地 PostgreSQL |

## 核心规则

- 客户注册只需要印度手机号、登录密码、邀请码。
- 客户注册不使用邮箱，不使用短信验证码。
- 后台员工使用员工编号和密码登录，不使用邮箱体系。
- 客户注册成功后，系统自动生成内部客户编号，客户 App 不展示。
- 注册后进入 KYC，可上传 Aadhaar 或 PAN，业务员后台审核。
- 客户入金不在 App 内提交申请，点击 Deposit / Contact Support 后进入在线客服，由财务后台手动上分。
- 客户提现在 App 内提交申请，系统生成提现订单号，客户记录和后台都可查看。
- 管理员、财务、客服可以查看所有客户；业务员只能查看自己的客户。
- 业务员可查看自己客户的入金、提现、订单、成交记录，但不能审核提现。
- 后台统一中文，客户 App 统一英文。

## 本地启动

先打开 Docker Desktop，然后在项目根目录执行：

```powershell
docker compose up -d postgres
```

初始化 API 数据库：

```powershell
cd apps/api
Copy-Item .env.example .env
npm run prisma:migrate
npm run seed
npm run start:dev
```

启动管理后台：

```powershell
cd ..\admin
Copy-Item .env.example .env.local
npm run dev
```

默认访问：

```text
API: http://localhost:3000
管理后台: http://localhost:3002/login
```

如需独立客服端：

```powershell
cd ..\support
Copy-Item .env.example .env.local
npm run dev
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
| 管理员 | `ADMIN001` | `Admin@123456` |
| 财务 | `FINANCE001` | `Finance@123456` |
| 客服 | `SUPPORT001` | `Support@123456` |
| 业务员 | `BUSINESS001` | `Business@123456` |

生产环境上线后请立即修改默认密码。

## 一键验收

完整检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1
```

快速检查，不跑业务冒烟：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -SkipVerification
```

验证脚本会检查 API、管理后台、独立客服端和客户 App，并覆盖注册、KYC、客服标签、财务上分、交易、提现订单号和角色数据权限。

## 文档

- `docs/本地启动与联调.md`
- `docs/运营流程说明.md`
- `docs/客户APP发布配置.md`
- `docs/交付验收清单.md`
- `docs/生产部署说明.md`
- `docs/项目交付总览.md`
