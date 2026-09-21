"use client";

import { Button, Result } from "antd";

type Props = {
  error: { digest?: string };
  reset: () => void;
};

export default function GlobalErrorPage({ error, reset }: Props) {
  return (
    <main className="ops-system-state" role="alert">
      <Result
        status="error"
        title="后台页面暂时无法显示"
        subTitle={error.digest ? `错误编号 ${error.digest}` : "请重试当前页面。不会展示堆栈或内部诊断。"}
        extra={
          <Button type="primary" aria-label="重试当前页面" onClick={() => reset()}>
            重试
          </Button>
        }
      />
    </main>
  );
}
