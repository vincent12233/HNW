"use client";

import { ReactNode } from "react";
import { Space, Typography } from "antd";

const { Title, Paragraph } = Typography;

type OpsPageHeaderProps = {
  title: string;
  description?: ReactNode;
  extra?: ReactNode;
  eyebrow?: string;
};

/** Shared page chrome for ops consoles — visual only, no auth changes. */
export default function OpsPageHeader({ title, description, extra, eyebrow = "OPERATIONS" }: OpsPageHeaderProps) {
  return (
    <div className="ops-page-header">
      <div className="ops-page-header-main">
        <span className="ops-page-eyebrow">{eyebrow}</span>
        <Title level={2} className="ops-page-title">
          {title}
        </Title>
        {description ? (
          <Paragraph type="secondary" className="ops-page-desc">
            {description}
          </Paragraph>
        ) : null}
      </div>
      {extra ? <Space wrap className="ops-page-extra">{extra}</Space> : null}
    </div>
  );
}
