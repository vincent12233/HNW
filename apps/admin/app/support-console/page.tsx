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
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import RecoveryInbox from "@/components/RecoveryInbox";
import { api, getApiErrorMessage } from '@/lib/api';
import { maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime } from "@/lib/ops-format";

const { Paragraph, Text } = Typography;

const supportTags = ["入金咨询", "提现问题", "KYC", "交易问题", "账户问题", "紧急", "已跟进"];

const defaultQuickReplies = [
  "您好，请按客服提供的存款方式付款并发送付款凭证。客服会转交信息，财务核实实际到账后为账户上分。",
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
  return formatOpsDateTime(value);
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
  const [quickReplies, setQuickReplies] = useState<string[]>(defaultQuickReplies);
  const [supportTagsState, setSupportTagsState] = useState<string[]>(supportTags);

  const selectedTags = useMemo(() => selected?.tags || [], [selected?.tags]);
  const selectedIdRef = useRef<string | null>(null);
  useEffect(() => {
    selectedIdRef.current = selected?.id ?? null;
  });

  const loadQuickReplies = useCallback(async () => {
    try {
      const response = await api.get<{
        support?: Record<string, { body?: string }>;
      }>("/support/desk-content", { params: { locale: "zh" } });
      const support = response.data?.support ?? {};
      const keys = [
        "quick_reply.deposit",
        "quick_reply.withdrawal",
        "quick_reply.kyc",
        "quick_reply.general",
      ] as const;
      // Merge by key so a missing CMS entry keeps the built-in default
      // instead of dropping that slot from the console toolbar.
      setQuickReplies(
        keys.map((key, index) => {
          const body = String(support[key]?.body ?? "").trim();
          return body || defaultQuickReplies[index];
        }),
      );
      const tags = String(support.tags?.body ?? "")
        .split(/[,，]/)
        .map((item) => item.trim())
        .filter(Boolean);
      if (tags.length > 0) setSupportTagsState(tags);
    } catch {
      // Keep built-in fallbacks when ops content is unavailable.
    }
  }, []);

  const loadMessages = useCallback(async (conversationId: string) => {
    setMessageLoading(true);

    try {
      const response = await api.get<SupportMessage[]>(
        `/support/conversations/${conversationId}/messages`,
      );
      setMessages(Array.isArray(response.data) ? response.data : []);
    } finally {
      setMessageLoading(false);
    }
  }, []);

  const loadConversations = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<Conversation[]>("/support/conversations");
      const list = Array.isArray(response.data) ? response.data : [];
      setConversations(list);

      const currentId = selectedIdRef.current;
      const nextSelected =
        currentId && list.find((item) => item.id === currentId)
          ? list.find((item) => item.id === currentId)!
          : list[0] || null;

      setSelected(nextSelected);

      if (nextSelected) {
        await loadMessages(nextSelected.id);
      }
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "客服会话加载失败",
      );
    } finally {
      setLoading(false);
    }
  }, [loadMessages]);

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

  async function translateSupportMessage(item: SupportMessage) {
    try {
      const response = await api.post<{
        translatedText?: string;
        summary?: string;
        suggestedReply?: string;
      }>("/support/translate", { content: item.content });
      setTranslated((current) => ({
        ...current,
        [item.id]:
          response.data.translatedText ||
          `${response.data.summary || ""}${response.data.suggestedReply || ""}` ||
          "翻译结果为空",
      }));
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      message.error(responseMessage || "翻译失败");
    }
  }

  useEffect(() => {
    void loadConversations();
    void loadQuickReplies();
  }, [loadConversations, loadQuickReplies]);

  return (
    <AdminShell>
      <RecoveryInbox />
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          eyebrow="SUPPORT"
          title="客服会话台"
          crumbs={[{ title: "客服" }, { title: "客服会话台" }]}
          description="处理客户咨询，支持客服标签、自定义备注标签、快捷回复和消息翻译辅助。客户看不到这些后台标签。本页不新增工单系统或客户经理入口。"
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void loadConversations()} aria-label="刷新客服会话">
              刷新
            </Button>
          }
        />

        {error ? <OpsErrorState title={error} onRetry={() => void loadConversations()} /> : null}

        <div className="ops-support-grid">
          <Card
            title="客户会话"
            extra={<Button icon={<ReloadOutlined />} loading={loading} onClick={loadConversations} />}
          >
            <List
              loading={loading}
              dataSource={conversations}
              locale={{ emptyText: <OpsEmpty description={loading ? "正在加载会话" : "暂无会话"} onRetry={loading ? undefined : () => void loadConversations()} /> }}
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
                        {item.client?.phone && <Tag>{maskOpsPhone(item.client.phone)}</Tag>}
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
                  {selected.client?.phone && <Tag>{maskOpsPhone(selected.client.phone)}</Tag>}
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
                  options={supportTagsState.map((tag) => ({ value: tag, label: tag }))}
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
                                onClick={() => translateSupportMessage(item)}
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
