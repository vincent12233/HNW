"use client";

import { Tag } from "antd";
import { suggestionColor, suggestionLabel, type VipSuggestionStatus } from "@/lib/vip";

export default function VipSuggestionTag({ status }: { status?: VipSuggestionStatus }) {
  return <Tag color={suggestionColor(status)}>{suggestionLabel(status)}</Tag>;
}
