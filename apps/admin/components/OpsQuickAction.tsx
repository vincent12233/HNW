import {
  Card,
  Space,
  Typography,
} from "antd";
import { RightOutlined } from "@ant-design/icons";
import type { ReactNode } from "react";
import Link from "next/link";

import type { OpsDashboardTone } from "@/lib/ops-dashboard";

const { Paragraph, Text } = Typography;

export default function OpsQuickAction({
  title,
  description,
  icon,
  tone,
  href,
}: {
  title: string;
  description: string;
  icon: ReactNode;
  tone: OpsDashboardTone;
  href: string;
}) {
  return (
    <Link href={href} className="ops-quick-action">
      <Card hoverable className="ops-quick-card" styles={{ body: { padding: 18 } }}>
        <Space align="start" className="ops-quick-layout">
          <Space align="start" className="ops-quick-content">
            <span className="ops-quick-icon" data-tone={tone} aria-hidden="true">
              {icon}
            </span>
            <div className="ops-quick-copy">
              <Text strong>{title}</Text>
              <Paragraph type="secondary" className="ops-quick-description">
                {description}
              </Paragraph>
            </div>
          </Space>
          <RightOutlined className="ops-quick-arrow" aria-hidden="true" />
        </Space>
      </Card>
    </Link>
  );
}
