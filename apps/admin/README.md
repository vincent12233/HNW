# HNW 管理后台

这是平台后台入口，按端口提供超级管理员、管理员、财务、业务员、专用运营员五个独立入口；五个入口共用同一个 API 和数据库，但按角色严格隔离会话和菜单。

## 本地启动

先复制环境变量：

```powershell
Copy-Item .env.example .env.local
```

默认 API 地址：

```env
NEXT_PUBLIC_API_URL=http://localhost:3000
```

启动后台：

```powershell
npm run dev
```

默认访问地址：

```text
http://localhost:3002/login
```

## 生产发布

正式部署见 `docs/生产部署说明.md`。**必须为五个角色分别构建**，因为 `NEXT_PUBLIC_*` 在构建时写入浏览器包；HTTPS 域名没有端口，不能依赖本机端口推断角色。

| 角色 | `NEXT_PUBLIC_BACKEND_ROLE` | 本机端口 | 启动命令 |
| --- | --- | --- | --- |
| 超级管理员 | `ADMIN` | `3002` | `npm run start:admin` |
| 管理员 | `MANAGER` | `3004` | `npm run start:manager` |
| 财务 | `FINANCE` | `3005` | `npm run start:finance` |
| 业务员 | `BUSINESS` | `3006` | `npm run start:business` |
| 专用运营员 | `SUPPORT` | `3007` | `npm run start:support` |

示例（超级管理员）：

```powershell
$env:NEXT_PUBLIC_API_URL="https://api.example.com"
$env:NEXT_PUBLIC_BACKEND_ROLE="ADMIN"
$env:NEXT_DIST_DIR=".next-ADMIN"
npm ci
npm run build
npm run start:admin
```

服务器上一键构建五个角色：

```bash
NEXT_PUBLIC_API_URL=https://api.example.com ./scripts/build-admin-roles.sh
```

对 `MANAGER` / `FINANCE` / `BUSINESS` / `SUPPORT` 分别用匹配的 `NEXT_DIST_DIR=.next-<ROLE>` 启动。API 的 `CORS_ORIGINS` 须包含全部五个后台域名（及可选客户 Web 域名）。完整说明见 `docs/生产部署说明.md`。

## 默认账号

本地种子数据会创建以下角色账号：

| 角色 | 员工编号 | 密码 |
| --- | --- | --- |
| 超级管理员 | ADMIN001 | `ADMIN_INITIAL_PASSWORD` 环境变量 |
| 管理员 | MANAGER001 | `MANAGER_INITIAL_PASSWORD` 环境变量 |
| 财务 | FINANCE001 | `FINANCE_INITIAL_PASSWORD` 环境变量 |
| 业务员 | BUSINESS001 | `BUSINESS_INITIAL_PASSWORD` 环境变量 |
| 专用运营员 | SUPPORT001 | `SUPPORT_INITIAL_PASSWORD` 环境变量 |

生产环境上线后请立即修改默认密码。
