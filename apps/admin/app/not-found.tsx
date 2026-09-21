"use client";

import { Button, Result } from "antd";
import { useRouter } from "next/navigation";

export default function NotFoundPage() {
  const router = useRouter();

  return (
    <main className="ops-system-state" role="main">
      <Result
        status="404"
        title="页面不存在"
        subTitle="当前地址没有对应的后台页面。权限和菜单范围没有因此扩大。"
        extra={
          <Button type="primary" aria-label="返回登录入口" onClick={() => router.replace("/login")}>
            返回登录入口
          </Button>
        }
      />
    </main>
  );
}
