"use client";

import { ReloadOutlined } from "@ant-design/icons";
import { Alert, Button } from "antd";
import type { ReactNode } from "react";

type Props = {
  title?: string;
  description?: ReactNode;
  onRetry?: () => void;
};

export default function OpsErrorState({
  title = "数据暂时不可用",
  description = "请检查网络后重试。当前页面没有使用缓存或占位结果。",
  onRetry,
}: Props) {
  return (
    <Alert
      className="ops-error-state"
      type="error"
      showIcon
      title={title}
      description={description}
      action={
        onRetry ? (
          <Button
            size="small"
            icon={<ReloadOutlined />}
            aria-label="重新加载"
            onClick={onRetry}
          >
            重试
          </Button>
        ) : undefined
      }
    />
  );
}
