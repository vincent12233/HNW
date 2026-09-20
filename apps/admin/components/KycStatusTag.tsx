"use client";

import { Space, Typography } from "antd";

import OpsStatusTag from "@/components/OpsStatusTag";
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
      <OpsStatusTag code={presentation.status === "UNKNOWN" ? status : presentation.status} label={presentation.label} />
      {presentation.resubmitHint ? (
        <Text type="secondary" className="kyc-resubmit-hint kyc-wrap-text">
          {presentation.resubmitHint}
        </Text>
      ) : null}
    </Space>
  );
}
