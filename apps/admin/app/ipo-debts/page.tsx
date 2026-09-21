"use client";

import { ExclamationCircleOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Card, Col, Input, Row, Space, Statistic, Table, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import { filterLoadedRows, maskOpsPhone } from "@/lib/ops-directory";
import { formatInr, formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { PRODUCT_COPY } from "@/lib/ops-product";

const { Text } = Typography;

type IpoDebt = {
  id: string;
  amount: string;
  paidAmount: string;
  outstandingAmount: string;
  status: string;
  createdAt: string;
  updatedAt: string;
  account: {
    accountNumber: string;
    user: { customerNo?: string | null; fullName: string; phone?: string | null };
  };
  application: {
    id: string;
    allocatedQuantity?: number | null;
    allocatedPrice?: string | null;
    paymentStatus: string;
    status: string;
  };
  ipo: { symbol: string; companyName: string; issuePrice: string };
};

export default function IpoDebtsPage() {
  const [rows, setRows] = useState<IpoDebt[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadRows() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<IpoDebt[]>("/admin/ipo/debts");
      setRows(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "IPO 欠款加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadRows();
  }, []);

  const filteredRows = useMemo(
    () =>
      filterLoadedRows(rows, keyword, (row) => [
        row.account.accountNumber,
        row.account.user.customerNo,
        row.account.user.fullName,
        maskOpsPhone(row.account.user.phone, ""),
        row.ipo.symbol,
        row.ipo.companyName,
        row.status,
      ]),
    [keyword, rows],
  );

  const totalOutstanding = filteredRows.reduce((sum, row) => sum + Number(row.outstandingAmount), 0);
  const overdueCount = filteredRows.filter((row) => row.status === "DEFAULTED").length;

  const columns: ColumnsType<IpoDebt> = [
    {
      title: "客户",
      width: 250,
      fixed: "left",
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <span className="ops-wrap-text">{row.account.user.fullName || "未命名客户"}</span>
          <Text type="secondary">{row.account.user.customerNo || "—"} · {maskOpsPhone(row.account.user.phone)}</Text>
        </Space>
      ),
    },
    { title: "交易账号", width: 160, render: (_, row) => <span className="ops-id">{row.account.accountNumber}</span> },
    {
      title: "IPO",
      width: 240,
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.ipo.symbol}</Text>
          <Text type="secondary" className="ops-wrap-text">{row.ipo.companyName}</Text>
        </Space>
      ),
    },
    { title: "中签数量", width: 120, render: (_, row) => row.application.allocatedQuantity ? `${row.application.allocatedQuantity} 股` : "—" },
    { title: "已付金额", dataIndex: "paidAmount", width: 140, align: "right", render: (value) => <OpsMoney value={value} /> },
    { title: "欠款金额", dataIndex: "outstandingAmount", width: 140, align: "right", render: (value) => <Text type={Number(value) > 0 ? "danger" : undefined}><OpsMoney value={value} /></Text> },
    { title: "付款状态", width: 120, render: (_, row) => <OpsStatusTag code={row.application.paymentStatus} /> },
    { title: "欠款状态", dataIndex: "status", width: 120, render: (value: string) => <OpsStatusTag code={value} /> },
    { title: "更新时间", dataIndex: "updatedAt", width: 180, render: (value: string) => formatOpsDateTime(value) },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={PRODUCT_COPY.ipoDebtsTitle}
          crumbs={[{ title: "产品" }, { title: PRODUCT_COPY.ipoDebtsTitle }]}
          description={`显示 IPO 分配后未补足的真实欠款。客户补款由财务上分自动抵扣，补足后系统自动转入持仓。${PRODUCT_COPY.noVip}`}
        />
        {error ? <OpsErrorState title={error} onRetry={loadRows} /> : null}
        <Row gutter={[16, 16]}>
          <Col xs={24} md={8}><Card><Statistic title="欠款总额" value={formatInr(totalOutstanding)} /></Card></Col>
          <Col xs={24} md={8}><Card><Statistic title="待跟进订单" value={filteredRows.filter((row) => row.status !== "PAID").length} /></Card></Col>
          <Col xs={24} md={8}><Card><Statistic title="逾期订单" value={overdueCount} prefix={<ExclamationCircleOutlined aria-hidden />} /></Card></Col>
        </Row>
        <OpsToolbar extra={<Button icon={<ReloadOutlined />} onClick={loadRows} loading={loading} aria-label="刷新 IPO 欠款">刷新</Button>}>
          <Input prefix={<SearchOutlined aria-hidden />} allowClear placeholder="搜索已加载的客户、交易账号或 IPO" value={keyword} onChange={(event) => setKeyword(event.target.value)} aria-label="搜索已加载的 IPO 欠款" style={{ width: 380, maxWidth: "100%" }} />
        </OpsToolbar>
        <Text type="secondary">{PRODUCT_COPY.loadedFilter}</Text>
        <Table<IpoDebt>
          rowKey="id"
          className="ops-directory-table"
          dataSource={filteredRows}
          columns={columns}
          loading={loading}
          scroll={{ x: 1480 }}
          pagination={OPS_TABLE_PAGINATION}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载欠款" : "当前没有 IPO 欠款。"} onRetry={loading ? undefined : loadRows} /> }}
        />
      </Space>
    </AdminShell>
  );
}
