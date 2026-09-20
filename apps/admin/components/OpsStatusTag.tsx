"use client";

import {
  CheckCircleOutlined,
  ClockCircleOutlined,
  CloseCircleOutlined,
  ExclamationCircleOutlined,
  MinusCircleOutlined,
  SyncOutlined,
} from "@ant-design/icons";
import { Tag } from "antd";
import type { ReactNode } from "react";

import { opsStatusOf, opsToneColor, type OpsTone } from "@/lib/ops-status";

const ICONS: Record<OpsTone, ReactNode> = {
  success: <CheckCircleOutlined aria-hidden />,
  warning: <ExclamationCircleOutlined aria-hidden />,
  error: <CloseCircleOutlined aria-hidden />,
  processing: <SyncOutlined spin aria-hidden />,
  info: <ClockCircleOutlined aria-hidden />,
  default: <MinusCircleOutlined aria-hidden />,
};

type Props = {
  code?: string | null;
  label?: string;
};

export default function OpsStatusTag({ code, label }: Props) {
  const spec = opsStatusOf(code);
  const text = label || spec.label;
  return (
    <Tag
      className="ops-status-tag"
      color={opsToneColor(spec.tone)}
      icon={ICONS[spec.tone]}
      aria-label={`状态 ${text}`}
    >
      {text}
    </Tag>
  );
}
