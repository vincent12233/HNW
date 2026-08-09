# HNW Trading API

这是平台后端服务，负责客户注册、KYC、账户资金、交易订单、提现、在线客服和后台管理接口。

## 本地启动

先准备环境变量：

```powershell
Copy-Item .env.example .env
```

启动数据库后执行迁移和种子：

```powershell
npm run prisma:migrate
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

上线前至少需要修改：

```env
DATABASE_URL=正式数据库连接
JWT_SECRET=高强度随机密钥
CORS_ORIGINS=https://admin.example.com,https://support.example.com
PORT=3000
```

`/health` 只返回 API 基础状态，不暴露用户数量、账户数量或业务数据。

## 默认种子账号

| 角色 | 员工编号 | 密码 |
| --- | --- | --- |
| 管理员 | ADMIN001 | Admin@123456 |
| 财务 | FINANCE001 | Finance@123456 |
| 客服 | SUPPORT001 | Support@123456 |
| 业务员 | BUSINESS001 | Business@123456 |

生产环境上线后请立即修改默认密码。

## 联调测试

项目根目录提供一键冒烟脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-test.ps1
```

该脚本会覆盖手机号注册、KYC、客服入金咨询、财务上分、提现申请、业务员可见提现记录等核心流程。
