"use client";

import {
  ReloadOutlined,
  SearchOutlined,
  SendOutlined,
} from "@ant-design/icons";
import {
  Button,
  Input,
  InputNumber,
  Modal,
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
import { api, getApiErrorMessage, mapApiErrorText } from "@/lib/api";
import { filterLoadedRows, maskOpsPhone } from "@/lib/ops-directory";
import { formatInr, formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { PRODUCT_COPY, ipoApplicationStatusLabel } from "@/lib/ops-product";

const { Text } = Typography;

type IpoApplication = {
  draftQuantity?: number | null;
  draftPrice?: string | null;
  publishedAt?: string | null;
  id: string;
  status: string;
  paymentStatus: string;
  allocatedQuantity?: number | null;
  allocatedPrice?: string | null;
  allocatedAmount?: string | null;
  createdAt: string;
  ipo: {
    symbol: string;
    companyName: string;
    issuePrice: string;
    totalShares?: number;
    availableShares?: number;
    reservedDraftShares?: number;
    remainingShares?: number;
    status: string;
  };
  account: {
    accountNumber: string;
    cashBalance: string;
    user: {
      customerNo?: string | null;
      fullName: string;
      phone?: string | null;
      status: string;
    };
  };
  debt?: { amount: string; paidAmount: string; status: string } | null;
};

function formatDate(value?: string | null) {
  return formatOpsDateTime(value);
}

export default function BusinessIpoPage() {
  const [items, setItems] = useState<IpoApplication[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState<React.Key[]>([]);
  const [publishing, setPublishing] = useState(false);
  const [publishingIds, setPublishingIds] = useState<string[] | null>(null);
  const canPublish = (row: IpoApplication) =>
    row.status === "PENDING" &&
    !row.publishedAt &&
    Number(row.draftQuantity) > 0 &&
    Number(row.draftPrice) > 0;

  async function publish(ids: string[]) {
    if (publishing || !ids.length) return;
    setPublishing(true);
    try {
      const { data } = await api.post<{
        published: number;
        results: { id: string; published: boolean; message?: string }[];
      }>("/business/my-ipo-applications/publish", { ids });
      const failed = data.results.filter((row) => !row.published);
      message.success(`已公布 ${data.published} 条分配结果并完成结算`);
      await loadItems();
      setSelected(failed.map((row) => row.id));
      if (failed.length) {
        const reasons = [
          ...new Set(
            failed
              .map((row) => row.message)
              .filter(Boolean)
              .map((msg) => mapApiErrorText(String(msg))),
          ),
        ];
        setError(
          `${failed.length} 条未公布${
            reasons.length ? `：${reasons.join('；')}` : ""
          }。请检查是否已分配、剩余股数、是否已处理及客户归属后重试。成功的申请不会重复扣款。`,
        );
      }
    } catch (error) {
      message.error(
        getApiErrorMessage(error, "公布未完成，请刷新状态确认后重试。"),
      );
    } finally {
      setPublishing(false);
    }
  }

  async function loadItems() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<IpoApplication[]>(
        "/business/my-ipo-applications",
      );
      setItems(Array.isArray(response.data) ? response.data : []);
      setSelected([]);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "IPO 申请加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  async function allocate(record: IpoApplication) {
    let quantity = String(record.draftQuantity ?? "");
    const price = record.ipo.issuePrice;

    Modal.confirm({
      title: "分配 IPO",
      content: (
        <Space orientation="vertical" style={{ width: "100%" }}>
          <Text>
            {record.ipo.symbol} / {record.ipo.companyName}
          </Text>
          <Text type="secondary">
            客户现金：{formatInr(record.account.cashBalance)}
            。保存分配不扣款，公布后才执行扣款、欠款及持仓处理。
          </Text>
          <Text type="secondary">
            剩余可分配股数：
            {record.ipo.remainingShares ?? record.ipo.availableShares ?? "—"}
            {record.ipo.totalShares != null
              ? ` / 发行总量 ${record.ipo.totalShares}`
              : ""}
            {record.ipo.reservedDraftShares
              ? `（其他草稿已占用 ${record.ipo.reservedDraftShares}）`
              : ""}
          </Text>
          <InputNumber
            min={1}
            max={
              record.ipo.remainingShares ??
              record.ipo.availableShares ??
              undefined
            }
            precision={0}
            defaultValue={record.draftQuantity ?? undefined}
            style={{ width: "100%" }}
            placeholder="分配数量"
            onChange={(value) => {
              quantity = String(value ?? "");
            }}
          />
          <Text>
            结算价（申购价）：{formatInr(record.ipo.issuePrice)}
          </Text>
          <Text type="secondary">
            分配结算固定使用超管申购价；不可超过剩余可分配股数（已扣除其他未公布草稿）。
          </Text>
        </Space>
      ),
      okText: "保存分配",
      cancelText: "取消",
      async onOk() {
        if (
          !Number.isInteger(Number(quantity)) ||
          Number(quantity) <= 0 ||
          !Number.isFinite(Number(price)) ||
          Number(price) <= 0
        ) {
          message.error("请输入有效的分配数量和价格");
          throw new Error("Invalid IPO allocation values");
        }
        if (
          (record.ipo.remainingShares ?? record.ipo.availableShares) != null &&
          Number(quantity) >
            Number(record.ipo.remainingShares ?? record.ipo.availableShares)
        ) {
          message.error(
            `分配数量不能超过剩余可分配股数（${
              record.ipo.remainingShares ?? record.ipo.availableShares
            }）`,
          );
          throw new Error("IPO allocation exceeds remaining shares");
        }
        try {
          await api.patch(
            `/business/my-ipo-applications/${record.id}/allocate`,
            {
              quantity: Number(quantity),
              price: Number(price).toFixed(2),
            },
          );
          message.success("分配已保存，公布后才会扣款");
          await loadItems();
        } catch (error) {
          message.error(
            getApiErrorMessage(error, "分配失败，请检查剩余股数后重试"),
          );
          throw error;
        }
      },
    });
  }

  useEffect(() => {
    loadItems();
  }, []);

  const filtered = useMemo(
    () =>
      filterLoadedRows(items, keyword, (item) => [
        item.ipo.symbol,
        item.ipo.companyName,
        item.account.accountNumber,
        item.account.user.customerNo,
        item.account.user.fullName,
        maskOpsPhone(item.account.user.phone, ""),
        item.status,
        item.paymentStatus,
      ]),
    [items, keyword],
  );

  const columns: ColumnsType<IpoApplication> = [
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
      key: "account",
      width: 160,
      render: (_, record) => <span className="ops-id">{record.account.accountNumber}</span>,
    },
    {
      title: "IPO",
      key: "ipo",
      width: 230,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.ipo.symbol}</Text>
          <Text type="secondary">{record.ipo.companyName}</Text>
        </Space>
      ),
    },
    {
      title: "发行价",
      key: "issuePrice",
      width: 120,
      align: "right",
      render: (_, record) => <OpsMoney value={record.ipo.issuePrice} />,
    },
    {
      title: "申请状态",
      width: 120,
      render: (_, row) => (
        <OpsStatusTag code={row.status} label={ipoApplicationStatusLabel(row.status, row.draftQuantity)} />
      ),
    },
    {
      title: "付款状态",
      dataIndex: "paymentStatus",
      width: 120,
      render: (value, row) => (
        <OpsStatusTag
          code={value}
          label={
            row.status === "PENDING"
              ? "未扣款"
              : value === "PAID"
                ? "已付款"
                : value === "PENDING"
                  ? "待补款"
                  : value === "FAILED"
                    ? "付款失败"
                    : undefined
          }
        />
      ),
    },
    {
      title: "分配数量",
      width: 120,
      render: (_, row) =>
        (row.status === "PENDING" ? row.draftQuantity : row.allocatedQuantity)
          ? `${row.status === "PENDING" ? row.draftQuantity : row.allocatedQuantity} 股`
          : "-",
    },
    {
      title: "分配单价",
      width: 120,
      render: (_, row) =>
        row.draftPrice || row.allocatedPrice
          ? <OpsMoney value={row.status === "PENDING" ? row.draftPrice : row.allocatedPrice} />
          : "—",
    },
    {
      title: "欠款",
      key: "debt",
      width: 130,
      align: "right",
      render: (_, record) =>
        record.debt
          ? <OpsMoney value={Number(record.debt.amount) - Number(record.debt.paidAmount)} />
          : "—",
    },
    {
      title: "申请时间",
      dataIndex: "createdAt",
      width: 180,
      render: formatDate,
    },
    {
      title: "操作",
      key: "actions",
      width: 190,
      fixed: "right",
      render: (_, record) => (
        <Space>
          <Button
            size="small"
            disabled={publishing || record.status !== "PENDING"}
            onClick={() => allocate(record)}
          >
            {record.draftQuantity ? "修改分配" : "分配"}
          </Button>
          <Button
            type="primary"
            size="small"
            icon={<SendOutlined />}
            disabled={publishing || !canPublish(record)}
            aria-label={`公布 ${record.ipo.symbol} 分配`}
            onClick={() => setPublishingIds([record.id])}
          >
            公布分配
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={PRODUCT_COPY.ipoAppsTitle}
          crumbs={[{ title: "产品" }, { title: PRODUCT_COPY.ipoAppsTitle }]}
          description={`先保存分配，再单个或批量公布。公布后自动扣款，不足部分生成欠款，补足后转入持仓。结果只在服务器成功后刷新。${PRODUCT_COPY.noVip}`}
        />
        {error ? <OpsErrorState title={error} onRetry={loadItems} /> : null}
        <OpsToolbar
          extra={
            <Space wrap>
              <Button icon={<ReloadOutlined />} onClick={loadItems} loading={loading} aria-label="刷新 IPO 申请">刷新</Button>
              <Button
                type="primary"
                icon={<SendOutlined />}
                loading={publishing}
                disabled={!selected.length}
                aria-label="批量公布分配"
                onClick={() => setPublishingIds(selected.map(String))}
              >
                批量公布（{selected.length}）
              </Button>
            </Space>
          }
        >
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder="搜索已加载的客户、交易账号或 IPO"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="搜索已加载的 IPO 申请"
            style={{ width: 420, maxWidth: "100%" }}
          />
        </OpsToolbar>
        <Text type="secondary">{PRODUCT_COPY.loadedFilter}</Text>
          <Table<IpoApplication>
            rowKey="id"
            className="ops-directory-table"
            columns={columns}
            dataSource={filtered}
            loading={loading}
            rowSelection={{
              selectedRowKeys: selected,
              onChange: setSelected,
              getCheckboxProps: (row) => ({
                disabled: publishing || !canPublish(row),
              }),
            }}
            scroll={{ x: 1760 }}
            pagination={OPS_TABLE_PAGINATION}
            locale={{ emptyText: <OpsEmpty description={loading ? "正在加载 IPO 申请" : "当前没有 IPO 申请。"} onRetry={loading ? undefined : loadItems} /> }}
          />
      </Space>
      <OpsModal
        title="确认公布分配并扣款"
        open={!!publishingIds}
        confirmLoading={publishing}
        onCancel={() => { if (!publishing) setPublishingIds(null); }}
        onOk={async () => {
          if (!publishingIds) return;
          await publish(publishingIds);
          setPublishingIds(null);
        }}
        okText="提交到服务器"
        cancelText="返回"
        zIndex={2100}
      >
        <Text>将公布 {publishingIds?.length ?? 0} 条分配结果。未扣款前状态保持当前值，失败记录不会从列表删除。</Text>
      </OpsModal>
    </AdminShell>
  );
}
