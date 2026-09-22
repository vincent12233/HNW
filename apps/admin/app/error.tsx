"use client";

import { Button, Result, Space } from "antd";
import { useRouter } from "next/navigation";

type Props = {
  error: { digest?: string };
  reset: () => void;
};

export default function GlobalErrorPage({ error, reset }: Props) {
  const router = useRouter();

  return (
    <main className="ops-system-state" role="alert">
      <Result
        status="error"
        title="后台页面暂时无法显示"
        subTitle={error.digest ? `错误编号 ${error.digest}` : "请重试当前页面。不会展示堆栈或内部诊断。"}
        extra={
          <Space wrap>
            <Button type="primary" aria-label="重试当前页面" onClick={() => reset()}>
              重试
            </Button>
            <Button aria-label="返回登录入口" onClick={() => router.replace("/login")}>
              返回登录入口
            </Button>
          </Space>
        }
      />
    </main>
  );
}
