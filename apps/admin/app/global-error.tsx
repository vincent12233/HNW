"use client";

import { Button, Result, Space } from "antd";
import "./globals.css";

type Props = {
  error: { digest?: string };
  reset: () => void;
};

export default function GlobalError({ error, reset }: Props) {
  return (
    <html lang="zh-CN">
      <body>
        <main className="ops-system-state" role="alert">
          <Result
            status="error"
            title="HNW Admin 暂时无法显示"
            subTitle={
              error.digest
                ? `错误编号 ${error.digest}。请返回登录入口或重试。不会展示堆栈或内部诊断。`
                : "请返回登录入口或重试当前页面。不会展示堆栈或内部诊断。"
            }
            extra={
              <Space wrap>
                <Button type="primary" aria-label="重试当前页面" onClick={() => reset()}>
                  重试
                </Button>
                <Button aria-label="返回登录入口" onClick={() => window.location.replace("/login")}>
                  返回登录入口
                </Button>
              </Space>
            }
          />
        </main>
      </body>
    </html>
  );
}
