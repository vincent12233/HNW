"use client";

import { EyeOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Descriptions, Input, Select, Space, Table, Tooltip, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useRef, useState } from "react";

import OpsDrawer from "@/components/OpsDrawer";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import { maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime, formatOpsId, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import {
  ORDER_SIDES,
  ORDER_STATUS_FILTER_OPTIONS,
  ORDER_TIFS,
  ORDER_TYPES,
  TRADING_COPY,
  orderStatusLabel,
  tradeFeeOf,
} from "@/lib/ops-trading";

const { Text } = Typography;

type TradeFill = {
  id?: string;
  executionId?: string;
  quantity?: number;
  price?: string | number;
  fees?: string | number;
  feeAmount?: string | number;
  netAmount?: string | number;
  executedAt?: string;
};

export type OpsOrderRecord = {
  id: string;
  clientOrderId: string;
  side: string;
  type?: string;
  timeInForce?: string;
  status: string;
  quantity: number;
  filledQuantity: number;
  limitPrice?: string | number | null;
  averageFillPrice?: string | number | null;
  frozenAmount?: string | number | null;
  rejectionReason?: string | null;
  placedAt: string;
  updatedAt?: string | null;
  completedAt?: string | null;
  cancelledAt?: string | null;
  trades?: TradeFill[];
  account: {
    accountNumber: string;
    user: {
      id?: string;
      customerNo?: string | null;
      fullName?: string | null;
      phone?: string | null;
    };
  };
  instrument: {
    exchange: string;
    symbol: string;
    name: string;
  };
};

type OrdersResponse = {
  data: OpsOrderRecord[];
  total: number;
  page?: number;
  pageSize?: number;
};

type Props = {
  title: string;
  description: string;
  crumbs: { title: string }[];
  listApi: string;
  searchPlaceholder: string;
};

export default function OpsOrderWorkspace({
  title,
  description,
  crumbs,
  listApi,
  searchPlaceholder,
}: Props) {
  const [records, setRecords] = useState<OpsOrderRecord[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<string | undefined>();
  const [side, setSide] = useState<string | undefined>();
  const [type, setType] = useState<string | undefined>();
  const [timeInForce, setTimeInForce] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [detail, setDetail] = useState<OpsOrderRecord | null>(null);
  const filtersRef = useRef({ search, status, side, type, timeInForce, page, pageSize });
  useEffect(() => {
    filtersRef.current = { search, status, side, type, timeInForce, page, pageSize };
  });

  const loadRecords = useCallback(async () => {
    const next = filtersRef.current;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<OrdersResponse>(listApi, {
        params: {
          page: next.page,
          pageSize: next.pageSize,
          search: next.search.trim() || undefined,
          status: next.status,
          side: next.side,
          type: next.type,
          timeInForce: next.timeInForce,
        },
      });
      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
      setTotal(Number(response.data.total) || 0);
    } catch (requestError: unknown) {
      setRecords([]);
      setTotal(0);
      setError(getApiErrorMessage(requestError, "") || "订单数据加载失败");
    } finally {
      setLoading(false);
    }
  }, [listApi]);

  useEffect(() => {
    void loadRecords();
  }, [loadRecords, page, pageSize]);

  function queryNow() {
    if (page !== 1) setPage(1);
    else void loadRecords();
  }

  const columns: ColumnsType<OpsOrderRecord> = [
    {
      title: "客户",
      fixed: "left",
      width: 220,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <span className="ops-wrap-text">{record.account.user.fullName || "未命名客户"}</span>
          <Text type="secondary">
            {record.account.user.customerNo || formatOpsId(record.account.user.id)} · {maskOpsPhone(record.account.user.phone)}
          </Text>
        </Space>
      ),
    },
    {
      title: "交易账号",
      width: 150,
      render: (_, record) => <span className="ops-id">{record.account.accountNumber}</span>,
    },
    {
      title: "标的",
      width: 160,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.instrument.symbol}</Text>
          <Text type="secondary">{record.instrument.exchange}</Text>
        </Space>
      ),
    },
    {
      title: "方向",
      dataIndex: "side",
      width: 96,
      render: (value: string) => <OpsStatusTag code={value} />,
    },
    {
      title: "类型",
      dataIndex: "type",
      width: 88,
      render: (value?: string) => (value ? <OpsStatusTag code={value} /> : "—"),
    },
    {
      title: "有效期",
      dataIndex: "timeInForce",
      width: 148,
      render: (value?: string) => (value ? <OpsStatusTag code={value} /> : "—"),
    },
    {
      title: "状态",
      dataIndex: "status",
      width: 120,
      render: (value: string) => <OpsStatusTag code={value} label={orderStatusLabel(value)} />,
    },
    { title: "数量", dataIndex: "quantity", width: 80, align: "right" },
    { title: "已成交", dataIndex: "filledQuantity", width: 88, align: "right" },
    {
      title: "限价",
      dataIndex: "limitPrice",
      width: 120,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "成交均价",
      dataIndex: "averageFillPrice",
      width: 120,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "客户订单号",
      dataIndex: "clientOrderId",
      width: 200,
      render: (value: string) => <span className="ops-id ops-wrap-text">{value}</span>,
    },
    {
      title: "下单时间",
      dataIndex: "placedAt",
      width: 170,
      render: (value: string) => <span className="ops-datetime">{formatOpsDateTime(value)}</span>,
    },
    {
      title: "操作",
      fixed: "right",
      width: 88,
      render: (_, record) => (
        <Tooltip title="查看订单详情">
          <Button
            size="small"
            icon={<EyeOutlined aria-hidden />}
            aria-label={`查看 ${record.clientOrderId} 的订单详情`}
            onClick={() => setDetail(record)}
          >
            详情
          </Button>
        </Tooltip>
      ),
    },
  ];

  const fills = detail?.trades || [];

  return (
    <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
      <OpsPageHeader title={title} crumbs={crumbs} description={description} />
      {error ? <OpsErrorState title={error} onRetry={loadRecords} /> : null}
      <OpsToolbar
        extra={
          <Space wrap>
            <Button type="primary" icon={<SearchOutlined />} loading={loading} onClick={queryNow} aria-label="查询订单">
              查询
            </Button>
            <Button icon={<ReloadOutlined />} loading={loading} onClick={loadRecords} aria-label="刷新订单列表">
              刷新
            </Button>
          </Space>
        }
      >
        <Input
          allowClear
          prefix={<SearchOutlined aria-hidden />}
          placeholder={searchPlaceholder}
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          onPressEnter={queryNow}
          aria-label={searchPlaceholder}
          style={{ width: 320, maxWidth: "100%" }}
        />
        <Select
          allowClear
          placeholder="方向"
          value={side}
          onChange={setSide}
          style={{ width: 120 }}
          aria-label="按买卖方向筛选"
          options={ORDER_SIDES.map((value) => ({ value, label: value === "BUY" ? "买入" : "卖出" }))}
        />
        <Select
          allowClear
          placeholder="状态"
          value={status}
          onChange={setStatus}
          style={{ width: 150 }}
          aria-label="按订单状态筛选"
          options={ORDER_STATUS_FILTER_OPTIONS}
        />
        <Select
          allowClear
          placeholder="类型"
          value={type}
          onChange={setType}
          style={{ width: 120 }}
          aria-label="按订单类型筛选"
          options={ORDER_TYPES.map((value) => ({ value, label: value === "MARKET" ? "市价" : "限价" }))}
        />
        <Select
          allowClear
          placeholder="有效期"
          value={timeInForce}
          onChange={setTimeInForce}
          style={{ width: 180 }}
          aria-label="按有效期筛选"
          options={ORDER_TIFS.map((value) => ({
            value,
            label: value === "DAY" ? "当日有效" : value === "IOC" ? "IOC" : "FOK",
          }))}
        />
      </OpsToolbar>
      <Table<OpsOrderRecord>
        rowKey="id"
        className="ops-directory-table"
        columns={columns}
        dataSource={records}
        loading={loading}
        tableLayout="fixed"
        scroll={{ x: 1980 }}
        pagination={{
          ...OPS_TABLE_PAGINATION,
          current: page,
          pageSize,
          total,
          onChange: (nextPage, nextSize) => {
            setPage(nextPage);
            setPageSize(nextSize);
          },
        }}
        locale={{
          emptyText: (
            <OpsEmpty
              description={loading ? "正在加载订单" : "当前没有订单记录。"}
              onRetry={loading ? undefined : loadRecords}
            />
          ),
        }}
      />
      <OpsDrawer
        title="订单详情"
        open={!!detail}
        onClose={() => setDetail(null)}
        width={560}
      >
        {detail ? (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
            <Text type="secondary">{TRADING_COPY.noCancel}</Text>
            <Descriptions size="small" column={1} bordered>
              <Descriptions.Item label="订单 ID">
                <span className="ops-id">{detail.id}</span>
              </Descriptions.Item>
              <Descriptions.Item label="客户订单号">
                <span className="ops-id ops-wrap-text">{detail.clientOrderId}</span>
              </Descriptions.Item>
              <Descriptions.Item label="客户">{detail.account.user.fullName || "未命名客户"}</Descriptions.Item>
              <Descriptions.Item label="脱敏手机号">{maskOpsPhone(detail.account.user.phone)}</Descriptions.Item>
              <Descriptions.Item label="交易账号">
                <span className="ops-id">{detail.account.accountNumber}</span>
              </Descriptions.Item>
              <Descriptions.Item label="标的">
                {detail.instrument.exchange} {detail.instrument.symbol}
              </Descriptions.Item>
              <Descriptions.Item label="方向">
                <OpsStatusTag code={detail.side} />
              </Descriptions.Item>
              <Descriptions.Item label="类型">
                {detail.type ? <OpsStatusTag code={detail.type} /> : "—"}
              </Descriptions.Item>
              <Descriptions.Item label="有效期">
                {detail.timeInForce ? <OpsStatusTag code={detail.timeInForce} /> : "—"}
              </Descriptions.Item>
              <Descriptions.Item label="状态">
                <OpsStatusTag code={detail.status} label={orderStatusLabel(detail.status)} />
              </Descriptions.Item>
              <Descriptions.Item label="数量">{detail.quantity}</Descriptions.Item>
              <Descriptions.Item label="已成交">{detail.filledQuantity}</Descriptions.Item>
              <Descriptions.Item label="限价">
                <OpsMoney value={detail.limitPrice} />
              </Descriptions.Item>
              <Descriptions.Item label="成交均价">
                <OpsMoney value={detail.averageFillPrice} />
              </Descriptions.Item>
              {detail.frozenAmount != null ? (
                <Descriptions.Item label="冻结金额">
                  <OpsMoney value={detail.frozenAmount} />
                </Descriptions.Item>
              ) : null}
              <Descriptions.Item label="拒绝原因">
                <span className="ops-wrap-text">{detail.rejectionReason || "—"}</span>
              </Descriptions.Item>
              <Descriptions.Item label="下单时间">{formatOpsDateTime(detail.placedAt)}</Descriptions.Item>
              <Descriptions.Item label="更新时间">{formatOpsDateTime(detail.updatedAt)}</Descriptions.Item>
              <Descriptions.Item label="完成时间">{formatOpsDateTime(detail.completedAt)}</Descriptions.Item>
              <Descriptions.Item label="撤单时间">{formatOpsDateTime(detail.cancelledAt)}</Descriptions.Item>
            </Descriptions>
            <div>
              <Text strong>接口返回的成交</Text>
              <ParagraphNote />
              {fills.length ? (
                <Table<TradeFill>
                  rowKey={(row, index) => row.executionId || row.id || String(index)}
                  size="small"
                  pagination={false}
                  dataSource={fills}
                  columns={[
                    {
                      title: "成交编号",
                      dataIndex: "executionId",
                      render: (value: string) => <span className="ops-id">{value || "—"}</span>,
                    },
                    { title: "数量", dataIndex: "quantity", align: "right" as const },
                    {
                      title: "价格",
                      dataIndex: "price",
                      align: "right" as const,
                      render: (value) => <OpsMoney value={value} />,
                    },
                    {
                      title: "费用",
                      align: "right" as const,
                      render: (_, row) => <OpsMoney value={tradeFeeOf(row)} />,
                    },
                    {
                      title: "时间",
                      dataIndex: "executedAt",
                      render: (value: string) => formatOpsDateTime(value),
                    },
                  ]}
                />
              ) : (
                <Text type="secondary">当前订单记录未返回成交明细。</Text>
              )}
            </div>
          </Space>
        ) : null}
      </OpsDrawer>
    </Space>
  );
}

function ParagraphNote() {
  return (
    <Text type="secondary" style={{ display: "block", margin: "8px 0" }}>
      {TRADING_COPY.tradesFromApi}
    </Text>
  );
}
