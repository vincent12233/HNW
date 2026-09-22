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
                ? `请重试。如仍无法打开，请联系管理员并提供错误编号 ${error.digest}。`
                : "请重试当前页面，或返回登录入口重新登录。"
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
