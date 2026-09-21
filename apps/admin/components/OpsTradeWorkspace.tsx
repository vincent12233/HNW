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
import { ORDER_SIDES, TRADING_COPY, orderStatusLabel, tradeFeeOf } from "@/lib/ops-trading";

const { Text } = Typography;

export type OpsTradeRecord = {
  id: string;
  executionId: string;
  quantity: number;
  price: string | number;
  grossAmount?: string | number;
  feeAmount?: string | number | null;
  fees?: string | number | null;
  netAmount?: string | number;
  executedAt: string;
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
  order: {
    id?: string;
    clientOrderId: string;
    side: string;
    type?: string;
    timeInForce?: string;
    status?: string;
  };
};

type TradesResponse = {
  data: OpsTradeRecord[];
  total: number;
};

type Props = {
  title: string;
  description: string;
  crumbs: { title: string }[];
  listApi: string;
  searchPlaceholder: string;
};

export default function OpsTradeWorkspace({
  title,
  description,
  crumbs,
  listApi,
  searchPlaceholder,
}: Props) {
  const [records, setRecords] = useState<OpsTradeRecord[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [search, setSearch] = useState("");
  const [side, setSide] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [detail, setDetail] = useState<OpsTradeRecord | null>(null);
  const filtersRef = useRef({ search, side, page, pageSize });
  useEffect(() => {
    filtersRef.current = { search, side, page, pageSize };
  });

  const loadRecords = useCallback(async () => {
    const next = filtersRef.current;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<TradesResponse>(listApi, {
        params: {
          page: next.page,
          pageSize: next.pageSize,
          search: next.search.trim() || undefined,
          side: next.side,
        },
      });
      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
      setTotal(Number(response.data.total) || 0);
    } catch (requestError: unknown) {
      setRecords([]);
      setTotal(0);
      setError(getApiErrorMessage(requestError, "") || "成交数据加载失败");
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

  const columns: ColumnsType<OpsTradeRecord> = [
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
      width: 150,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.instrument.symbol}</Text>
          <Text type="secondary">{record.instrument.exchange}</Text>
        </Space>
      ),
    },
    {
      title: "方向",
      width: 96,
      render: (_, record) => <OpsStatusTag code={record.order.side} />,
    },
    { title: "数量", dataIndex: "quantity", width: 80, align: "right" },
    {
      title: "成交价",
      dataIndex: "price",
      width: 120,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "成交金额",
      dataIndex: "grossAmount",
      width: 130,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "手续费",
      width: 110,
      align: "right",
      render: (_, record) => <OpsMoney value={tradeFeeOf(record)} />,
    },
    {
      title: "净额",
      dataIndex: "netAmount",
      width: 130,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "成交编号",
      dataIndex: "executionId",
      width: 200,
      render: (value: string) => <span className="ops-id ops-wrap-text">{value}</span>,
    },
    {
      title: "客户订单号",
      width: 200,
      render: (_, record) => <span className="ops-id ops-wrap-text">{record.order.clientOrderId}</span>,
    },
    {
      title: "成交时间",
      dataIndex: "executedAt",
      width: 170,
      render: (value: string) => <span className="ops-datetime">{formatOpsDateTime(value)}</span>,
    },
    {
      title: "操作",
      fixed: "right",
      width: 88,
      render: (_, record) => (
        <Tooltip title="查看成交详情">
          <Button
            size="small"
            icon={<EyeOutlined aria-hidden />}
            aria-label={`查看成交 ${record.executionId}`}
            onClick={() => setDetail(record)}
          >
            详情
          </Button>
        </Tooltip>
      ),
    },
  ];

  return (
    <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
      <OpsPageHeader title={title} crumbs={crumbs} description={description} />
      {error ? <OpsErrorState title={error} onRetry={loadRecords} /> : null}
      <OpsToolbar
        extra={
          <Space wrap>
            <Button type="primary" icon={<SearchOutlined />} loading={loading} onClick={queryNow} aria-label="查询成交">
              查询
            </Button>
            <Button icon={<ReloadOutlined />} loading={loading} onClick={loadRecords} aria-label="刷新成交列表">
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
          style={{ width: 360, maxWidth: "100%" }}
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
      </OpsToolbar>
      <Table<OpsTradeRecord>
        rowKey="id"
        className="ops-directory-table"
        columns={columns}
        dataSource={records}
        loading={loading}
        tableLayout="fixed"
        scroll={{ x: 1960 }}
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
              description={loading ? "正在加载成交" : "当前没有成交记录。"}
              onRetry={loading ? undefined : loadRecords}
            />
          ),
        }}
      />
      <OpsDrawer title="成交详情" open={!!detail} onClose={() => setDetail(null)} width={520}>
        {detail ? (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
            <Text type="secondary">{TRADING_COPY.tradesDesc}</Text>
            <Descriptions size="small" column={1} bordered>
              <Descriptions.Item label="成交 ID">
                <span className="ops-id">{detail.id}</span>
              </Descriptions.Item>
              <Descriptions.Item label="成交编号">
                <span className="ops-id">{detail.executionId}</span>
              </Descriptions.Item>
              <Descriptions.Item label="关联订单">
                <span className="ops-id">{detail.order.clientOrderId}</span>
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
                <OpsStatusTag code={detail.order.side} />
              </Descriptions.Item>
              <Descriptions.Item label="订单状态">
                {detail.order.status ? (
                  <OpsStatusTag code={detail.order.status} label={orderStatusLabel(detail.order.status)} />
                ) : (
                  "—"
                )}
              </Descriptions.Item>
              <Descriptions.Item label="数量">{detail.quantity}</Descriptions.Item>
              <Descriptions.Item label="成交价">
                <OpsMoney value={detail.price} />
              </Descriptions.Item>
              <Descriptions.Item label="成交金额">
                <OpsMoney value={detail.grossAmount} />
              </Descriptions.Item>
              <Descriptions.Item label="手续费">
                <OpsMoney value={tradeFeeOf(detail)} />
              </Descriptions.Item>
              <Descriptions.Item label="净额">
                <OpsMoney value={detail.netAmount} />
              </Descriptions.Item>
              <Descriptions.Item label="成交时间">{formatOpsDateTime(detail.executedAt)}</Descriptions.Item>
            </Descriptions>
            <Text type="secondary">{TRADING_COPY.feeZero}</Text>
          </Space>
        ) : null}
      </OpsDrawer>
    </Space>
  );
}
