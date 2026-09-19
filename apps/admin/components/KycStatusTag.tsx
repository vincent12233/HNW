"use client";

import { Space, Tag, Typography } from "antd";

import { kycStatusPresentation } from "@/lib/kyc-review";

const { Text } = Typography;

type Props = {
  status: string;
  reviewNote?: string | null;
};

export default function KycStatusTag({ status, reviewNote }: Props) {
  const presentation = kycStatusPresentation(status, reviewNote);
  return (
    <Space orientation="vertical" size={0}>
      <Tag color={presentation.color}>{presentation.label}</Tag>
      {presentation.resubmitHint ? (
        <Text type="secondary" className="kyc-resubmit-hint">
          {presentation.resubmitHint}
        </Text>
      ) : null}
    </Space>
  );
}
