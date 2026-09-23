# HNW Trading API

这是平台后端服务，负责客户注册、KYC、账户资金、交易订单、提现、在线客服和后台管理接口。

## 本地启动

先准备环境变量：

```powershell
Copy-Item .env.example .env
```

启动数据库后执行迁移和种子：

```powershell
npm run db:generate
npm run db:migrate
npm run seed
```

启动 API：

```powershell
npm run start:dev
```

默认地址：

```text
http://localhost:3000
```

## 生产配置

正式部署完整清单见仓库根目录 `docs/生产部署说明.md`。上线前至少配置：

```env
NODE_ENV=production
DATABASE_URL=正式数据库连接
RATE_LIMIT_REDIS_URL=redis://正式Redis地址:6379
JWT_SECRET=≥32位高强度随机密钥
TWO_FACTOR_ENCRYPTION_KEY=独立≥32位密钥
OTC_KEY_ENCRYPTION_SECRET=另一组≥32位密钥
OBJECT_SIGNING_SECRET=第三组≥32位密钥
ADMIN_FIXED_INVITE_CODE=≥12位强唯一邀请码
ADMIN_INITIAL_PASSWORD=≥12位
FINANCE_INITIAL_PASSWORD=≥12位
SUPPORT_INITIAL_PASSWORD=≥12位
BUSINESS_INITIAL_PASSWORD=≥12位
MANAGER_INITIAL_PASSWORD=≥12位
CORS_ORIGINS=https://admin.example.com,https://manager.example.com,https://finance.example.com,https://business.example.com,https://operator.example.com,https://app.example.com
VIRUS_SCAN_URL=https://malware-scanner.example.com/scan
PRIVATE_OBJECT_ROOT=/var/lib/hnw/private-objects
PORT=3000
```

生产启动：`npm run start:prod`（`NODE_ENV=production node dist/main.js`）。`/health` 与 `/health/ready` 只返回基础状态，不暴露业务数据。

`create-*-user` 脚本在 `NODE_ENV=production` 下会拒绝执行；本地脚本与 seed 一样，再次 upsert **不会覆盖**已有密码哈希。

## 默认种子账号

| 角色 | 员工编号 | 密码 |
| --- | --- | --- |
| 超级管理员 | ADMIN001 | `ADMIN_INITIAL_PASSWORD` 环境变量 |
| 管理员 | MANAGER001 | `MANAGER_INITIAL_PASSWORD` 环境变量 |
| 财务 | FINANCE001 | `FINANCE_INITIAL_PASSWORD` 环境变量 |
| 专用运营员 | SUPPORT001 | `SUPPORT_INITIAL_PASSWORD` 环境变量 |
| 业务员 | BUSINESS001 | `BUSINESS_INITIAL_PASSWORD` 环境变量 |

项目不再提供固定默认密码。初始化前必须配置至少 12 位的独立密码，且脚本不会在日志中输出密码。

## 联调测试

项目根目录提供一键冒烟脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verification-test.ps1
```

该脚本会覆盖手机号注册、KYC、客服入金咨询、财务上分、提现申请、业务员可见提现记录等核心流程。
