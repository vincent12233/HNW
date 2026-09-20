"use client";

import {
  ArrowDownOutlined,
  ArrowUpOutlined,
  CheckCircleOutlined,
  MinusCircleOutlined,
} from "@ant-design/icons";
import type { ReactNode } from "react";
import { Tag, Tooltip } from "antd";
import { suggestionColor, suggestionLabel, type VipSuggestionStatus } from "@/lib/vip";

const ICONS: Record<VipSuggestionStatus, ReactNode> = {
  UPGRADE: <ArrowUpOutlined aria-hidden />,
  DOWNGRADE: <ArrowDownOutlined aria-hidden />,
  NOT_CONFIGURED: <MinusCircleOutlined aria-hidden />,
  KEEP: <CheckCircleOutlined aria-hidden />,
  NO_MATCH: <CheckCircleOutlined aria-hidden />,
};

export default function VipSuggestionTag({ status }: { status?: VipSuggestionStatus }) {
  const label = suggestionLabel(status);
  return (
    <Tooltip title={label}>
      <Tag
        color={suggestionColor(status)}
        icon={ICONS[status ?? "KEEP"]}
        className="vip-suggestion-tag"
        aria-label={label}
      >
        <span className="vip-suggestion-text">{label}</span>
      </Tag>
    </Tooltip>
  );
}
