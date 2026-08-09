# HNW 独立客服端

这是独立在线客服工作台。主后台也包含客服控制台；如果只想给客服一个更轻量入口，可以部署这个应用。

## 本地启动

```powershell
Copy-Item .env.example .env.local
npm run dev
```

默认 API 地址：

```env
NEXT_PUBLIC_API_URL=http://localhost:3000
```

## 登录账号

本地种子数据默认客服账号：

```text
员工编号：SUPPORT001
密码：Support@123456
```

生产环境上线后请修改默认密码。
