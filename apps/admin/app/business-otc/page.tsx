"use client";

import {
  CheckOutlined,
  CloseOutlined,
  ReloadOutlined,
  SearchOutlined,
} from "@ant-design/icons";
import {
  Button,
  Input,
  Space,
  Table,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import { filterLoadedRows } from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { PRODUCT_COPY } from "@/lib/ops-product";

const { Text } = Typography;

type OtcOrder = {
  id: string;
  orderNo: string;
  quantity: number;
  price: string;
  amount: string;
  status: "PENDING" | "APPROVED" | "REJECTED";
  createdAt: string;
  instrument: { symbol: string; name: string };
  account: {
    accountNumber: string;
    user: { fullName: string; phone?: string };
  };
};

export default function BusinessOtcPage() {
  const [items, setItems] = useState<OtcOrder[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [reviewing, setReviewing] = useState<string | null>(null);
  const [keyword, setKeyword] = useState("");
  const [confirming, setConfirming] = useState<{ order: OtcOrder; decision: "approve" | "reject" } | null>(null);

  async function load() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<OtcOrder[]>("/otc/orders/pending");
      setItems(response.data ?? []);
    } catch {
      setError("OTC 待审核订单加载失败，请刷新重试。");
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => {
    void load();
  }, []);

  const filtered = useMemo(
    () =>
      filterLoadedRows(items, keyword, (item) => [
        item.orderNo,
        item.instrument.symbol,
        item.instrument.name,
        item.account.accountNumber,
        item.account.user.fullName,
        item.status,
      ]),
    [items, keyword],
  );

  async function review(id: string, decision: "approve" | "reject") {
    if (reviewing) return;
    setReviewing(id);
    try {
      await api.patch(
        `/otc/orders/${id}/${decision}`,
        decision === "reject" ? { note: "Rejected by backend review" } : {},
      );
      message.success(
        decision === "approve"
          ? "审核通过，已完成结算并转入持仓"
          : "订单已拒绝",
      );
      setConfirming(null);
      await load();
    } catch (error) {
      message.error(
        getApiErrorMessage(error, "审核未完成，请刷新订单状态后重试。"),
      );
    } finally {
      setReviewing(null);
    }
  }

  const columns: ColumnsType<OtcOrder> = [
    {
      title: "订单编号",
      dataIndex: "orderNo",
      width: 210,
      render: (v) => <Text copyable>{v}</Text>,
    },
    {
      title: "客户 / 账户",
      width: 190,
      render: (_, r) => (
        <Space orientation="vertical" size={0}>
          <span className="ops-wrap-text">{r.account.user.fullName}</span>
          <Text type="secondary" className="ops-id">{r.account.accountNumber}</Text>
        </Space>
      ),
    },
    {
      title: "股票",
      width: 170,
      render: (_, r) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{r.instrument.symbol}</Text>
          <Text type="secondary" className="ops-wrap-text">{r.instrument.name}</Text>
        </Space>
      ),
    },
    { title: "数量", dataIndex: "quantity", align: "right", width: 100 },
    {
      title: "折扣结算价",
      dataIndex: "price",
      align: "right",
      width: 140,
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "订单金额",
      dataIndex: "amount",
      align: "right",
      width: 150,
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "状态",
      dataIndex: "status",
      width: 120,
      render: (v: OtcOrder["status"]) => <OpsStatusTag code={v} />,
    },
    {
      title: "申请时间",
      dataIndex: "createdAt",
      width: 180,
      render: (value: string) => formatOpsDateTime(value),
    },
    {
      title: "操作",
      fixed: "right",
      width: 190,
      render: (_, r) => (
        <Space>
          <Button
            type="primary"
            size="small"
            icon={<CheckOutlined />}
            disabled={!!reviewing}
            loading={reviewing === r.id}
            aria-label={`通过 ${r.orderNo}`}
            onClick={() => setConfirming({ order: r, decision: "approve" })}
          >
            通过
          </Button>
          <Button
            danger
            size="small"
            icon={<CloseOutlined />}
            disabled={!!reviewing}
            aria-label={`拒绝 ${r.orderNo}`}
            onClick={() => setConfirming({ order: r, decision: "reject" })}
          >
            拒绝
          </Button>
        </Space>
      ),
    },
  ];
  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={PRODUCT_COPY.otcTitle}
          crumbs={[{ title: "产品" }, { title: PRODUCT_COPY.otcTitle }]}
          description={`仅展示当前账号权限范围内的 OTC 待审核订单。审核通过后自动结算资金并转入客户持仓。结果只在服务器成功后刷新。${PRODUCT_COPY.noVip}`}
        />
        {error ? <OpsErrorState title={error} onRetry={load} /> : null}
        <OpsToolbar extra={<Button icon={<ReloadOutlined />} loading={loading} onClick={load} aria-label="刷新 OTC 订单">刷新</Button>}>
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder="搜索已加载的订单号、客户、账户或股票"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="搜索已加载的 OTC 订单"
            style={{ width: 360, maxWidth: "100%" }}
          />
        </OpsToolbar>
        <Text type="secondary">{PRODUCT_COPY.loadedFilter}</Text>
        <Table
          rowKey="id"
          className="ops-directory-table"
          columns={columns}
          dataSource={filtered}
          loading={loading}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载 OTC 订单" : "暂无待审核的 OTC 订单"} onRetry={loading ? undefined : load} /> }}
          pagination={OPS_TABLE_PAGINATION}
          scroll={{ x: 1250 }}
        />
      </Space>
      <OpsModal
        title={confirming?.decision === "reject" ? "确认拒绝 OTC 订单" : "确认通过 OTC 订单"}
        open={!!confirming}
        confirmLoading={!!reviewing}
        onCancel={() => { if (!reviewing) setConfirming(null); }}
        onOk={() => confirming && review(confirming.order.id, confirming.decision)}
        okText="提交到服务器"
        cancelText="返回"
        okButtonProps={{ danger: confirming?.decision === "reject" }}
        zIndex={2100}
      >
        {confirming ? (
          <Space orientation="vertical">
            <Text>{confirming.order.orderNo} · {confirming.order.account.user.fullName} · <OpsMoney value={confirming.order.amount} /></Text>
            <Text type="secondary">
              {confirming.decision === "approve"
                ? "通过后将结算资金并转入客户持仓。未成功前状态保持待审核。"
                : "拒绝不会从列表删除失败记录。"}
            </Text>
          </Space>
        ) : null}
      </OpsModal>
    </AdminShell>
  );
}
