"use client";

import {
  ReloadOutlined,
  SearchOutlined,
  SendOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Input,
  InputNumber,
  Modal,
  Popconfirm,
  Space,
  Table,
  Tag,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

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

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function BusinessIpoPage() {
  const [items, setItems] = useState<IpoApplication[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState<React.Key[]>([]);
  const [publishing, setPublishing] = useState(false);
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
      if (failed.length)
        setError(
          `${failed.length} 条未公布，请检查是否已分配、是否已处理及客户归属后重试。成功的申请不会重复扣款。`,
        );
    } catch {
      message.error("公布未完成，请刷新状态确认后重试。");
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
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "IPO 申请加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  async function allocate(record: IpoApplication) {
    let quantity = String(record.draftQuantity ?? "");
    let price = record.draftPrice || record.ipo.issuePrice;

    Modal.confirm({
      title: "分配 IPO",
      content: (
        <Space orientation="vertical" style={{ width: "100%" }}>
          <Text>
            {record.ipo.symbol} / {record.ipo.companyName}
          </Text>
          <Text type="secondary">
            客户现金：{formatMoney(record.account.cashBalance)}
            。保存分配不扣款，公布后才执行扣款、欠款及持仓处理。
          </Text>
          <InputNumber
            min={1}
            precision={0}
            defaultValue={record.draftQuantity ?? undefined}
            style={{ width: "100%" }}
            placeholder="分配数量"
            onChange={(value) => {
              quantity = String(value ?? "");
            }}
          />
          <InputNumber
            min={0.01}
            precision={2}
            style={{ width: "100%" }}
            placeholder="分配价格"
            defaultValue={Number(price)}
            onChange={(value) => {
              price = String(value ?? "");
            }}
          />
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
        await api.patch(`/business/my-ipo-applications/${record.id}/allocate`, {
          quantity: Number(quantity),
          price: Number(price).toFixed(2),
        });
        message.success("分配已保存，公布后才会扣款");
        await loadItems();
      },
    });
  }

  useEffect(() => {
    loadItems();
  }, []);

  const filtered = useMemo(() => {
    const value = keyword.trim().toLowerCase();
    if (!value) return items;
    return items.filter((item) =>
      [
        item.ipo.symbol,
        item.ipo.companyName,
        item.account.accountNumber,
        item.account.user.customerNo,
        item.account.user.fullName,
        item.account.user.phone,
        item.status,
        item.paymentStatus,
      ].some((field) =>
        String(field ?? "")
          .toLowerCase()
          .includes(value),
      ),
    );
  }, [items, keyword]);

  const columns: ColumnsType<IpoApplication> = [
    {
      title: "客户",
      key: "customer",
      width: 240,
      fixed: "left",
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.account.user.fullName || "未命名客户"}</Text>
          <Text type="secondary">
            {record.account.user.customerNo || "-"} / +91{" "}
            {record.account.user.phone || "-"}
          </Text>
        </Space>
      ),
    },
    {
      title: "交易账号",
      key: "account",
      width: 160,
      render: (_, record) => record.account.accountNumber,
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
      render: (_, record) => formatMoney(record.ipo.issuePrice),
    },
    {
      title: "申请状态",
      width: 120,
      render: (_, row) => (
        <Tag color={row.status === "PENDING" ? "orange" : "blue"}>
          {row.status === "PENDING"
            ? row.draftQuantity
              ? "待公布分配"
              : "待分配"
            : (
                {
                  ALLOTTED: "已公布分配",
                  APPROVED: "已通过",
                  REJECTED: "已拒绝",
                } as Record<string, string>
              )[row.status] || "未知状态"}
        </Tag>
      ),
    },
    {
      title: "付款状态",
      dataIndex: "paymentStatus",
      width: 120,
      render: (value, row) => (
        <Tag color={value === "PAID" ? "green" : "orange"}>
          {row.status === "PENDING"
            ? "未扣款"
            : (
                {
                  PAID: "已付款",
                  PENDING: "待补款",
                  FAILED: "付款失败",
                } as Record<string, string>
              )[value] || "未知状态"}
        </Tag>
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
          ? formatMoney(
              row.status === "PENDING" ? row.draftPrice : row.allocatedPrice,
            )
          : "-",
    },
    {
      title: "欠款",
      key: "debt",
      width: 130,
      align: "right",
      render: (_, record) =>
        record.debt
          ? formatMoney(
              Number(record.debt.amount) - Number(record.debt.paidAmount),
            )
          : "-",
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
          <Popconfirm
            title="确认公布分配结果并执行扣款？"
            okText="公布并结算"
            cancelText="取消"
            onConfirm={() => publish([record.id])}
            disabled={publishing || !canPublish(record)}
          >
            <Button
              type="primary"
              size="small"
              icon={<SendOutlined />}
              disabled={publishing || !canPublish(record)}
            >
              公布分配
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>IPO 分配</Title>
          <Paragraph type="secondary">
            先保存分配，再单个或批量公布。公布后自动扣款，不足部分生成欠款，补足后转入持仓。
          </Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
        <Card>
          <Space
            wrap
            style={{
              width: "100%",
              justifyContent: "space-between",
              marginBottom: 16,
            }}
          >
            <Input
              allowClear
              prefix={<SearchOutlined />}
              placeholder="搜索客户、手机号、交易账号或 IPO"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              style={{ width: 420 }}
            />
            <Button
              icon={<ReloadOutlined />}
              onClick={loadItems}
              loading={loading}
            >
              刷新
            </Button>
            <Popconfirm
              title={`公布所选 ${selected.length} 条分配结果并执行扣款？`}
              okText="批量公布并结算"
              cancelText="取消"
              onConfirm={() => publish(selected.map(String))}
              disabled={!selected.length || publishing}
            >
              <Button
                type="primary"
                icon={<SendOutlined />}
                loading={publishing}
                disabled={!selected.length}
              >
                批量公布（{selected.length}）
              </Button>
            </Popconfirm>
          </Space>
          <Table<IpoApplication>
            rowKey="id"
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
            pagination={{
              pageSize: 15,
              showTotal: (total) => `共 ${total} 条 IPO 申请`,
            }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
