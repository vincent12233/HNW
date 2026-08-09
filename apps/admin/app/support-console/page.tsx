"use client";

import {
  MessageOutlined,
  ReloadOutlined,
  SendOutlined,
  TranslationOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Empty,
  Input,
  List,
  Select,
  Space,
  Tag,
  Typography,
  message,
} from "antd";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

const supportTags = ["入金咨询", "提现问题", "KYC", "交易问题", "账户问题", "紧急", "已跟进"];

const quickReplies = [
  "您好，客户入金请先确认付款凭证和到账信息，财务确认后会为账户上分。",
  "您的提现申请已收到，财务会根据订单号核对并处理。",
  "请上传清晰的 Aadhaar 或 PAN 文件，业务员会尽快审核 KYC。",
  "请提供手机号、客户姓名和问题截图，我们马上为您核查。",
];

type Conversation = {
  id: string;
  status: string;
  tags?: string[];
  internalNote?: string | null;
  priority?: string | null;
  createdAt: string;
  updatedAt: string;
  client?: {
    id: string;
    customerNo?: string | null;
    fullName: string;
    phone?: string | null;
  };
  messages?: Array<{
    id: string;
    content: string;
    createdAt: string;
  }>;
};

type SupportMessage = {
  id: string;
  content: string;
  senderType: "CLIENT" | "SUPPORT" | "ADMIN";
  createdAt: string;
};

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

function translateMessage(content: string) {
  const lower = content.toLowerCase();

  if (lower.includes("deposit")) {
    return "客户在咨询入金。可回复：请提供付款凭证，客服确认信息后转财务上分。";
  }

  if (lower.includes("withdraw")) {
    return "客户在咨询提现。可回复：请提供提现订单号，财务会审核处理。";
  }

  if (lower.includes("kyc") || lower.includes("aadhaar") || lower.includes("pan")) {
    return "客户在咨询 KYC。可回复：请上传清晰的 Aadhaar 或 PAN 文件等待审核。";
  }

  if (/[\u4e00-\u9fff]/.test(content)) {
    return "检测到中文消息。可根据客户内容回复英文，或转交会英语的客服继续处理。";
  }

  return "暂未匹配到内置翻译。后续可接入真实翻译 API，用于自动中英互译。";
}

export default function SupportConsolePage() {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selected, setSelected] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [content, setContent] = useState("");
  const [translated, setTranslated] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [messageLoading, setMessageLoading] = useState(false);
  const [error, setError] = useState("");

  const selectedTags = useMemo(() => selected?.tags || [], [selected?.tags]);

  async function loadConversations() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<Conversation[]>("/support/conversations");
      const list = Array.isArray(response.data) ? response.data : [];
      setConversations(list);

      const nextSelected =
        selected && list.find((item) => item.id === selected.id)
          ? list.find((item) => item.id === selected.id)!
          : list[0] || null;

      setSelected(nextSelected);

      if (nextSelected) {
        await loadMessages(nextSelected.id);
      }
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "客服会话加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  async function loadMessages(conversationId: string) {
    setMessageLoading(true);

    try {
      const response = await api.get<SupportMessage[]>(
        `/support/conversations/${conversationId}/messages`,
      );
      setMessages(Array.isArray(response.data) ? response.data : []);
    } finally {
      setMessageLoading(false);
    }
  }

  async function updateTags(tags: string[]) {
    if (!selected) return;

    await api.post(`/support/conversations/${selected.id}/tags`, { tags });
    setSelected({ ...selected, tags });
    setConversations((items) =>
      items.map((item) => (item.id === selected.id ? { ...item, tags } : item)),
    );
    message.success("标签已更新");
  }

  async function updateMeta(patch: Partial<Pick<Conversation, "internalNote" | "priority" | "status">>) {
    if (!selected) return;

    await api.post(`/support/conversations/${selected.id}/meta`, patch);
    const next = { ...selected, ...patch };
    setSelected(next);
    setConversations((items) => items.map((item) => (item.id === selected.id ? { ...item, ...patch } : item)));
    message.success("会话信息已更新");
  }

  async function sendMessage() {
    if (!selected || !content.trim()) return;

    await api.post("/support/messages", {
      conversationId: selected.id,
      content: content.trim(),
    });

    setContent("");
    message.success("已发送");
    await loadMessages(selected.id);
    await loadConversations();
  }

  useEffect(() => {
    loadConversations();
  }, []);

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>在线客服后台</Title>
          <Paragraph type="secondary">
            处理客户咨询，支持客服标签、自定义备注标签、快捷回复和消息翻译辅助。客户看不到这些后台标签。
          </Paragraph>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        <div style={{ display: "grid", gridTemplateColumns: "360px minmax(0, 1fr)", gap: 16 }}>
          <Card
            title="客户会话"
            extra={<Button icon={<ReloadOutlined />} loading={loading} onClick={loadConversations} />}
          >
            <List
              loading={loading}
              dataSource={conversations}
              locale={{ emptyText: <Empty description="暂无会话" /> }}
              renderItem={(item) => (
                <List.Item
                  onClick={() => {
                    setSelected(item);
                    loadMessages(item.id);
                  }}
                  style={{
                    cursor: "pointer",
                    paddingInline: 8,
                    background: selected?.id === item.id ? "#eef6ff" : undefined,
                    borderRadius: 8,
                  }}
                >
                  <List.Item.Meta
                    avatar={<MessageOutlined />}
                    title={
                      <Space wrap>
                        <Text strong>{item.client?.fullName || "客户"}</Text>
                        {item.client?.customerNo && <Tag>{item.client.customerNo}</Tag>}
                        {item.client?.phone && <Tag>+91 {item.client.phone}</Tag>}
                      </Space>
                    }
                    description={
                      <Space orientation="vertical" size={4}>
                        <Text type="secondary" ellipsis>
                          {item.messages?.[0]?.content || formatDate(item.updatedAt)}
                        </Text>
                        <Space wrap size={4}>
                          {(item.tags || []).map((tag) => (
                            <Tag key={tag} color={tag === "紧急" ? "red" : "blue"}>
                              {tag}
                            </Tag>
                          ))}
                        </Space>
                      </Space>
                    }
                  />
                </List.Item>
              )}
            />
          </Card>

          <Card
            title={
              selected ? (
                <Space wrap>
                  <span>{selected.client?.fullName || "客户"}</span>
                  {selected.client?.customerNo && <Tag>{selected.client.customerNo}</Tag>}
                  {selected.client?.phone && <Tag>+91 {selected.client.phone}</Tag>}
                </Space>
              ) : (
                "聊天窗口"
              )
            }
            style={{ minHeight: 680 }}
          >
            {!selected ? (
              <Empty description="请选择一个客户会话" />
            ) : (
              <Space orientation="vertical" style={{ width: "100%" }} size="middle">
                <Select
                  mode="tags"
                  allowClear
                  tokenSeparators={[",", "，", " "]}
                  value={selectedTags}
                  onChange={updateTags}
                  placeholder="选择或输入自定义备注标签"
                  style={{ width: "100%" }}
                  options={supportTags.map((tag) => ({ value: tag, label: tag }))}
                />

                <Space wrap style={{ width: "100%", justifyContent: "space-between" }}>
                  <Space wrap>
                    <Select
                      value={selected.priority || "普通"}
                      style={{ width: 130 }}
                      onChange={(priority) => updateMeta({ priority })}
                      options={[
                        { value: "普通", label: "普通" },
                        { value: "重要", label: "重要" },
                        { value: "紧急", label: "紧急" },
                      ]}
                    />
                    <Tag color={selected.status === "OPEN" ? "green" : "default"}>
                      {selected.status === "OPEN" ? "进行中" : "已关闭"}
                    </Tag>
                  </Space>
                  <Space>
                    <Button size="small" onClick={() => updateMeta({ status: "OPEN" })}>
                      重开
                    </Button>
                    <Button size="small" danger onClick={() => updateMeta({ status: "CLOSED" })}>
                      关闭
                    </Button>
                  </Space>
                </Space>

                <Input.TextArea
                  value={selected.internalNote || ""}
                  placeholder="内部备注，客户不可见"
                  autoSize={{ minRows: 2, maxRows: 3 }}
                  onBlur={(event) => updateMeta({ internalNote: event.target.value })}
                />

                <Space wrap>
                  {quickReplies.map((reply) => (
                    <Button key={reply} size="small" onClick={() => setContent(reply)}>
                      {reply.slice(0, 16)}...
                    </Button>
                  ))}
                </Space>

                <div
                  style={{
                    height: 430,
                    overflowY: "auto",
                    padding: 12,
                    background: "#f7f9fc",
                    borderRadius: 8,
                  }}
                >
                  <List
                    loading={messageLoading}
                    dataSource={messages}
                    renderItem={(item) => {
                      const isClient = item.senderType === "CLIENT";

                      return (
                        <List.Item style={{ justifyContent: isClient ? "flex-start" : "flex-end" }}>
                          <div
                            style={{
                              maxWidth: "76%",
                              padding: "10px 12px",
                              borderRadius: 8,
                              background: isClient ? "#fff" : "#dff1ff",
                              border: "1px solid #e8edf5",
                            }}
                          >
                            <Space style={{ width: "100%", justifyContent: "space-between" }}>
                              <Text strong>{isClient ? "客户" : "客服"}</Text>
                              <Button
                                type="text"
                                size="small"
                                icon={<TranslationOutlined />}
                                onClick={() =>
                                  setTranslated((current) => ({
                                    ...current,
                                    [item.id]: translateMessage(item.content),
                                  }))
                                }
                              >
                                翻译
                              </Button>
                            </Space>
                            <Paragraph style={{ marginBottom: 4 }}>{item.content}</Paragraph>
                            {translated[item.id] && (
                              <Alert
                                type="info"
                                showIcon
                                style={{ marginBottom: 8 }}
                                message={translated[item.id]}
                              />
                            )}
                            <Text type="secondary" style={{ fontSize: 12 }}>
                              {formatDate(item.createdAt)}
                            </Text>
                          </div>
                        </List.Item>
                      );
                    }}
                  />
                </div>

                <Space.Compact style={{ width: "100%" }}>
                  <Input.TextArea
                    value={content}
                    onChange={(event) => setContent(event.target.value)}
                    placeholder="输入回复内容"
                    autoSize={{ minRows: 2, maxRows: 4 }}
                  />
                  <Button type="primary" icon={<SendOutlined />} onClick={sendMessage}>
                    发送
                  </Button>
                </Space.Compact>
              </Space>
            )}
          </Card>
        </div>
      </Space>
    </AdminShell>
  );
}
