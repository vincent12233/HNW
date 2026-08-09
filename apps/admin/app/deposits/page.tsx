"use client";

import { DollarOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Form,
  Input,
  InputNumber,
  Modal,
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

type AccountRecord = {
  id: string;
  accountNumber: string;
  currency: string;
  balances: {
    cashBalance: string;
    buyingPower: string;
    frozenBalance: string;
    holdingsMarketValue: string;
    totalAsset: string;
  };
  user: {
    id: string;
    customerNo?: string | null;
    fullName: string;
    phone?: string | null;
    status: string;
  };
};

type AccountResponse = {
  data: AccountRecord[];
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

export default function DepositsPage() {
  const [records, setRecords] = useState<AccountRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState<AccountRecord | null>(null);
  const [form] = Form.useForm();

  async function loadRecords() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<AccountResponse>("/admin/accounts", {
        params: { page: 1, pageSize: 100, search: keyword.trim() || undefined },
      });

      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "账户数据加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadRecords();
  }, []);

  const filteredRecords = useMemo(() => {
    const normalized = keyword.trim().toLowerCase();
    if (!normalized) return records;

    return records.filter((record) => {
      const values = [
        record.user.fullName,
        record.user.customerNo,
        record.user.phone,
        record.accountNumber,
      ];

      return values.some((value) =>
        String(value ?? "").toLowerCase().includes(normalized),
      );
    });
  }, [keyword, records]);

  function openCredit(record: AccountRecord) {
    setSelected(record);
    form.setFieldsValue({
      amount: undefined,
      referenceId: `DEP-${Date.now()}`,
      note: "",
    });
  }

  async function submitCredit() {
    if (!selected) return;

    const values = await form.validateFields();
    setSubmitting(true);

    try {
      await api.post(`/admin/accounts/${selected.accountNumber}/credit`, {
        amount: Number(values.amount).toFixed(2),
        referenceId: values.referenceId,
        note: values.note || "财务手动上分",
      });

      message.success("上分成功");
      setSelected(null);
      await loadRecords();
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      message.error(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "上分失败",
      );
    } finally {
      setSubmitting(false);
    }
  }

  const columns: ColumnsType<AccountRecord> = [
    {
      title: "客户",
      key: "customer",
      fixed: "left",
      width: 240,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.user.fullName || "未命名客户"}</Text>
          <Text type="secondary">
            {record.user.customerNo || "-"} / +91 {record.user.phone || "-"}
          </Text>
        </Space>
      ),
    },
    { title: "交易账号", dataIndex: "accountNumber", width: 170 },
    {
      title: "现金",
      key: "cash",
      align: "right",
      width: 150,
      render: (_, record) => formatMoney(record.balances.cashBalance),
    },
    {
      title: "可用资金",
      key: "buyingPower",
      align: "right",
      width: 150,
      render: (_, record) => formatMoney(record.balances.buyingPower),
    },
    {
      title: "持仓市值",
      key: "holdings",
      align: "right",
      width: 150,
      render: (_, record) => formatMoney(record.balances.holdingsMarketValue),
    },
    {
      title: "状态",
      key: "status",
      width: 110,
      render: (_, record) => (
        <Tag color={record.user.status === "ACTIVE" ? "green" : "red"}>
          {record.user.status === "ACTIVE" ? "正常" : record.user.status}
        </Tag>
      ),
    },
    {
      title: "操作",
      key: "actions",
      fixed: "right",
      width: 130,
      render: (_, record) => (
        <Button type="primary" icon={<DollarOutlined />} onClick={() => openCredit(record)}>
          上分
        </Button>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>财务上分</Title>
          <Paragraph type="secondary">
            客户通过在线客服获取充值方式，付款确认后由财务在这里按交易账号手动上分。
          </Paragraph>
        </div>

        {error && <Alert type="error" title={error} showIcon />}

        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input.Search
              allowClear
              prefix={<SearchOutlined />}
              placeholder="搜索客户姓名、客户编号、手机号或交易账号"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              onSearch={loadRecords}
              style={{ width: 420 }}
            />

            <Button icon={<ReloadOutlined />} onClick={loadRecords} loading={loading}>
              刷新
            </Button>
          </Space>

          <Table<AccountRecord>
            rowKey="id"
            columns={columns}
            dataSource={filteredRecords}
            loading={loading}
            scroll={{ x: 1250 }}
          />
        </Card>
      </Space>

      <Modal
        title="财务上分"
        open={!!selected}
        onCancel={() => setSelected(null)}
        onOk={submitCredit}
        confirmLoading={submitting}
        okText="确认上分"
        cancelText="取消"
      >
        {selected && (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
            <Alert
              type="info"
              showIcon
              message={`${selected.user.fullName || "未命名客户"} / ${selected.accountNumber}`}
              description={`当前现金：${formatMoney(selected.balances.cashBalance)}`}
            />

            <Form form={form} layout="vertical">
              <Form.Item
                name="amount"
                label="上分金额"
                rules={[{ required: true, message: "请输入上分金额" }]}
              >
                <InputNumber min={0.01} precision={2} prefix="₹" style={{ width: "100%" }} />
              </Form.Item>

              <Form.Item
                name="referenceId"
                label="付款流水号"
                rules={[{ required: true, message: "请输入付款流水号" }]}
              >
                <Input />
              </Form.Item>

              <Form.Item name="note" label="备注">
                <Input.TextArea rows={3} placeholder="可填写客服确认信息、付款渠道或财务备注" />
              </Form.Item>
            </Form>
          </Space>
        )}
      </Modal>
    </AdminShell>
  );
}
