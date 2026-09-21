"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Input, Space, Table, Typography } from "antd";
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
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { FUNDING_COPY } from "@/lib/ops-funding";

const { Text } = Typography;

type DepositRecord = {
  id: string;
  amount: string | number;
  status: string;
  referenceId?: string | null;
  note?: string | null;
  createdAt: string;
  account: {
    id: string;
    accountNumber: string;
    currency: string;
    user: {
      id: string;
      customerNo?: string | null;
      fullName: string;
      phone?: string | null;
      status: string;
    };
  };
  createdBy?: {
    fullName?: string | null;
    role?: string | null;
  } | null;
};

export default function BusinessDepositsPage() {
  const [records, setRecords] = useState<DepositRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadRecords() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<DepositRecord[]>("/business/my-deposits");
      setRecords(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "入金记录加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadRecords();
  }, []);

  const filteredRecords = useMemo(
    () =>
      filterLoadedRows(records, keyword, (record) => [
        record.account.user.customerNo,
        record.account.user.fullName,
        maskOpsPhone(record.account.user.phone, ""),
        record.account.accountNumber,
        record.referenceId,
        record.note,
        record.status,
      ]),
    [keyword, records],
  );

  const columns: ColumnsType<DepositRecord> = [
    {
      title: "客户",
      key: "customer",
      width: 240,
      fixed: "left",
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <span className="ops-wrap-text">{record.account.user.fullName || "未命名客户"}</span>
          <Text type="secondary">
            {record.account.user.customerNo || "—"} · {maskOpsPhone(record.account.user.phone)}
          </Text>
        </Space>
      ),
    },
    {
      title: "交易账号",
      key: "accountNumber",
      width: 170,
      render: (_, record) => <span className="ops-id">{record.account.accountNumber}</span>,
    },
    {
      title: "入金金额",
      dataIndex: "amount",
      key: "amount",
      width: 150,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "状态",
      dataIndex: "status",
      key: "status",
      width: 120,
      render: (value: string) => <OpsStatusTag code={value} label={value === "COMPLETED" ? "已完成" : undefined} />,
    },
    {
      title: "流水号",
      dataIndex: "referenceId",
      key: "referenceId",
      width: 190,
      render: (value) => <span className="ops-wrap-text">{value || "—"}</span>,
    },
    {
      title: "财务操作员",
      key: "operator",
      width: 150,
      render: (_, record) => record.createdBy?.fullName || record.createdBy?.role || "—",
    },
    {
      title: "备注",
      dataIndex: "note",
      key: "note",
      width: 220,
      render: (value) => <span className="ops-wrap-text">{value || "—"}</span>,
    },
    {
      title: "完成时间",
      dataIndex: "createdAt",
      key: "createdAt",
      width: 180,
      render: (value: string) => formatOpsDateTime(value),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={FUNDING_COPY.businessDepositsTitle}
          crumbs={[{ title: "资金" }, { title: FUNDING_COPY.businessDepositsTitle }]}
          description={`这里只显示自己名下客户已由财务完成上分的记录，业务员没有审核或上分权限。${FUNDING_COPY.noGateway} ${FUNDING_COPY.noVipPriority}`}
        />

        {error ? <OpsErrorState title={error} onRetry={loadRecords} /> : null}

        <OpsToolbar extra={<Button icon={<ReloadOutlined />} onClick={loadRecords} loading={loading} aria-label="刷新入金记录">刷新</Button>}>
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder="搜索已加载的客户编号、姓名、交易账号或流水号"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="搜索已加载的入金记录"
            style={{ width: 420, maxWidth: "100%" }}
          />
        </OpsToolbar>
        <Text type="secondary">{FUNDING_COPY.loadedFilter}</Text>

        <Table<DepositRecord>
          rowKey="id"
          className="ops-directory-table"
          columns={columns}
          dataSource={filteredRecords}
          loading={loading}
          scroll={{ x: 1420 }}
          pagination={OPS_TABLE_PAGINATION}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载入金记录" : "当前没有入金记录。"} onRetry={loading ? undefined : loadRecords} /> }}
        />
      </Space>
    </AdminShell>
  );
}
