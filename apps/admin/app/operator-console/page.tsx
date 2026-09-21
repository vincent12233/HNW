"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Input, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import ScopedEditButton from "@/components/ScopedEditButton";
import { api, getApiErrorMessage } from "@/lib/api";
import { filterLoadedRows, maskBankAccount, maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime } from "@/lib/ops-format";
import { GOVERNANCE_COPY } from "@/lib/ops-governance";

const { Text } = Typography;

type Customer = {
  id: string;
  customerNo?: string | null;
  fullName: string;
  phone?: string | null;
  status: string;
  createdAt: string;
  usedInviteCode?: { code: string; usedAt?: string | null } | null;
  account?: {
    accountNumber: string;
    cashBalance: string | number;
    buyingPower: string | number;
    frozenBalance: string | number;
    currency: string;
    isLive: boolean;
  } | null;
};

export default function OperatorConsolePage() {
  const [rows, setRows] = useState<Customer[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<Customer[]>("/operator/customers");
      setRows(Array.isArray(data) ? data : []);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "专用运营员客户数据加载失败"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const filtered = useMemo(
    () =>
      filterLoadedRows(rows, keyword, (row) => [
        row.fullName,
        row.phone,
        row.customerNo,
        row.account?.accountNumber,
        row.usedInviteCode?.code,
      ]),
    [keyword, rows],
  );

  const activeCount = useMemo(() => rows.filter((row) => row.status === "ACTIVE").length, [rows]);

  const columns: ColumnsType<Customer> = [
    {
      title: "客户",
      width: 200,
      fixed: "left",
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong className="ops-wrap-text">{row.fullName}</Text>
          <Text type="secondary">{row.customerNo || "—"}</Text>
        </Space>
      ),
    },
    {
      title: "手机号",
      dataIndex: "phone",
      width: 140,
      render: (value?: string | null) => maskOpsPhone(value),
    },
    {
      title: "交易账号",
      width: 160,
      render: (_, row) => maskBankAccount(row.account?.accountNumber),
    },
    {
      title: "固定邀请码",
      width: 140,
      render: (_, row) => row.usedInviteCode?.code || "—",
    },
    {
      title: "现金余额",
      width: 150,
      align: "right",
      render: (_, row) => <OpsMoney value={row.account?.cashBalance} />,
    },
    {
      title: "可用资金",
      width: 150,
      align: "right",
      render: (_, row) => <OpsMoney value={row.account?.buyingPower} />,
    },
    {
      title: "状态",
      width: 110,
      render: (_, row) => <OpsStatusTag code={row.status} />,
    },
    {
      title: "注册时间",
      dataIndex: "createdAt",
      width: 180,
      render: (value: string) => formatOpsDateTime(value),
    },
    {
      title: "操作",
      fixed: "right",
      width: 160,
      render: (_, row) => (
        <ScopedEditButton
          name={row.fullName}
          current={row.status}
          kind="status"
          endpoint={`/business/customers/${row.id}/status`}
          onSaved={load}
        />
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          eyebrow="SUPPORT SCOPE"
          title="固定邀请码客户"
          description={`仅显示使用超级管理员固定邀请码注册的客户。普通业务员邀请码客户不会出现在此页，权限范围保持隔离。${GOVERNANCE_COPY.loadedFilter}`}
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()} aria-label="刷新固定邀请码客户">
              刷新
            </Button>
          }
        />

        <div className="ops-stat-strip">
          <div className="ops-stat-pill">
            <span className="label">专用范围客户</span>
            <span className="value">{rows.length}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">正常状态</span>
            <span className="value">{activeCount}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">当前筛选</span>
            <span className="value">{filtered.length}</span>
          </div>
        </div>

        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}

        <OpsToolbar>
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder="姓名、手机号、客户号、账户号或邀请码"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="筛选已加载的固定邀请码客户"
            style={{ width: 360, maxWidth: "100%" }}
          />
          <Tag color="blue">专用运营员范围</Tag>
        </OpsToolbar>
        <Table
          rowKey="id"
          className="ops-directory-table"
          loading={loading}
          dataSource={filtered}
          columns={columns}
          scroll={{ x: 1400 }}
          pagination={{ pageSize: 20, showTotal: (total) => `共 ${total} 位客户` }}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载客户" : "当前范围内没有客户。"} onRetry={loading ? undefined : () => void load()} /> }}
        />
      </Space>
    </AdminShell>
  );
}
