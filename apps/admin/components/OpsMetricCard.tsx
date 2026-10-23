import { Card, Space, Statistic } from "antd";
import type { ReactNode } from "react";

import type { OpsDashboardTone } from "@/lib/ops-dashboard";

export default function OpsMetricCard({
  title,
  value,
  icon,
  tone,
  suffix,
}: {
  title: string;
  value: string | number;
  icon: ReactNode;
  tone: OpsDashboardTone;
  suffix?: string;
}) {
  return (
    <Card className="ops-metric-card">
      <Space align="start" className="ops-metric-layout">
        <Statistic title={title} value={value} suffix={suffix} />
        <span className="ops-metric-icon" data-tone={tone} aria-hidden="true">
          {icon}
        </span>
      </Space>
    </Card>
  );
}
