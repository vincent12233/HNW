"use client";

import { InboxOutlined } from "@ant-design/icons";
import { Button, Empty } from "antd";
import type { ReactNode } from "react";

type Props = {
  description?: ReactNode;
  extra?: ReactNode;
  onRetry?: () => void;
};

export default function OpsEmpty({
  description = "暂无记录",
  extra,
  onRetry,
}: Props) {
  return (
    <Empty
      className="ops-empty"
      image={<InboxOutlined className="ops-empty-icon" aria-hidden />}
      description={description}
    >
      {extra}
      {onRetry ? (
        <Button aria-label="重新加载" onClick={onRetry}>
          重新加载
        </Button>
      ) : null}
    </Empty>
  );
}
