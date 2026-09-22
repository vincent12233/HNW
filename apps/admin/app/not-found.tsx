"use client";

import { Button, Result, Space } from "antd";
import { useRouter } from "next/navigation";

export default function NotFoundPage() {
  const router = useRouter();

  return (
    <main className="ops-system-state" role="main">
      <Result
        status="404"
        title="页面不存在"
        subTitle="页面可能已移动，或地址输入有误。请检查地址，或返回工作台从菜单重新打开。"
        extra={
          <Space wrap>
            <Button type="primary" aria-label="返回登录入口" onClick={() => router.replace("/login")}>
              返回登录入口
            </Button>
            <Button aria-label="返回工作台" onClick={() => router.replace("/dashboard")}>
              返回工作台
            </Button>
          </Space>
        }
      />
    </main>
  );
}
