"use client";

import { Space } from "antd";
import AdminShell from "@/components/AdminShell";
import OpsHealthPanel from "@/components/OpsHealthPanel";
import OpsPageHeader from "@/components/OpsPageHeader";

export default function SystemHealthPage() {
  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          title="系统健康"
          crumbs={[{ title: "系统治理" }, { title: "系统健康" }]}
          description="只读展示 API、数据库、行情和交易时段探针。Unavailable 表示探针没有返回，不代表健康。"
        />
        <OpsHealthPanel />
      </Space>
    </AdminShell>
  );
}
