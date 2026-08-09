# HNW 管理后台

这是平台后台入口，包含管理员、财务、客服、业务员四类角色页面。

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

发布前把 `NEXT_PUBLIC_API_URL` 改成正式 API 域名，例如：

```env
NEXT_PUBLIC_API_URL=https://api.example.com
```

同时在 API 服务的 `CORS_ORIGINS` 中加入后台域名，例如：

```env
CORS_ORIGINS=https://admin.example.com
```

构建命令：

```powershell
npm run build
```

## 默认账号

本地种子数据会创建以下角色账号：

| 角色 | 员工编号 | 密码 |
| --- | --- | --- |
| 管理员 | ADMIN001 | Admin@123456 |
| 财务 | FINANCE001 | Finance@123456 |
| 客服 | SUPPORT001 | Support@123456 |
| 业务员 | BUSINESS001 | Business@123456 |

生产环境上线后请立即修改默认密码。
