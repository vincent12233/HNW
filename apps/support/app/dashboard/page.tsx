"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { api } from "@/lib/api";

type Conversation = {
  id: string;
  tags?: string[];
  status?: string;
  createdAt?: string;
  updatedAt: string;
  client?: {
    fullName?: string | null;
    phone?: string | null;
    customerNo?: string | null;
  };
  messages?: Array<{
    content: string;
    createdAt: string;
  }>;
};

type SupportMessage = {
  id: string;
  content: string;
  senderType: "CLIENT" | "SUPPORT" | "ADMIN";
  createdAt: string;
  attachmentName?: string | null;
  attachmentUrl?: string | null;
  attachmentType?: string | null;
};

const presetTags = ["入金咨询", "提现问题", "KYC", "交易问题", "账户问题", "紧急", "已跟进"];

const quickReplies = [
  "您好，客户入金请先确认付款凭证和到账信息，财务确认后会为账户上分。",
  "您的提现申请已收到，请提供提现订单号，财务会核对并处理。",
  "请上传清晰的 Aadhaar 或 PAN 文件，业务员会尽快审核 KYC。",
  "请提供手机号、客户姓名和问题截图，我们马上为您核查。",
];

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function Dashboard() {
  const router = useRouter();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selected, setSelected] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [content, setContent] = useState("");
  const [keyword, setKeyword] = useState("");
  const [tagInput, setTagInput] = useState("");
  const [translated, setTranslated] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");

  const customerTitle = useMemo(() => {
    if (!selected) return "请选择客户会话";
    const name = selected.client?.fullName || "未命名客户";
    const phone = selected.client?.phone ? `+91 ${selected.client.phone}` : "-";
    return `${name} / ${phone}`;
  }, [selected]);

  const filteredConversations = useMemo(() => {
    const query = keyword.trim().toLowerCase();
    if (!query) return conversations;

    return conversations.filter((item) => {
      const haystack = [
        item.client?.fullName,
        item.client?.phone,
        item.client?.customerNo,
        item.messages?.[0]?.content,
        ...(item.tags || []),
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      return haystack.includes(query);
    });
  }, [conversations, keyword]);

  const selectedTags = useMemo(() => selected?.tags || [], [selected]);

  async function loadConversations() {
    setLoading(true);
    setError("");

    try {
      const response = await api("/support/conversations");
      const data = await response.json();

      if (!response.ok) {
        setError(Array.isArray(data.message) ? data.message.join("，") : data.message || "会话加载失败");
        return;
      }

      const list = Array.isArray(data) ? data : data.data || [];
      setConversations(list);

      const nextSelected =
        selected && list.find((item: Conversation) => item.id === selected.id)
          ? list.find((item: Conversation) => item.id === selected.id)
          : list[0] || null;

      setSelected(nextSelected);
      if (nextSelected) await loadMessages(nextSelected.id);
    } catch {
      setError("无法连接服务器");
    } finally {
      setLoading(false);
    }
  }

  async function loadMessages(conversationId: string) {
    const response = await api(`/support/conversations/${conversationId}/messages`);
    const data = await response.json();
    setMessages(Array.isArray(data) ? data : data.data || []);
    await api(`/support/conversations/${conversationId}/read`, { method: "POST" });
  }

  async function updateTags(nextTags: string[]) {
    if (!selected) return;

    const normalizedTags = Array.from(
      new Set(nextTags.map((tag) => tag.trim()).filter(Boolean).map((tag) => tag.slice(0, 24))),
    ).slice(0, 12);

    const response = await api(`/support/conversations/${selected.id}/tags`, {
      method: "POST",
      body: JSON.stringify({ tags: normalizedTags }),
    });

    if (!response.ok) {
      const data = await response.json();
      setError(Array.isArray(data.message) ? data.message.join("，") : data.message || "标签更新失败");
      return;
    }

    const nextSelected = { ...selected, tags: normalizedTags };
    setSelected(nextSelected);
    setConversations((items) =>
      items.map((item) => (item.id === selected.id ? { ...item, tags: normalizedTags } : item)),
    );
  }

  async function addTag(tag: string) {
    if (!tag.trim()) return;
    await updateTags([...selectedTags, tag]);
    setTagInput("");
  }

  async function removeTag(tag: string) {
    await updateTags(selectedTags.filter((item) => item !== tag));
  }

  async function sendMessage() {
    if (!selected || !content.trim()) return;

    setSending(true);
    try {
      const response = await api("/support/messages", {
        method: "POST",
        body: JSON.stringify({
          conversationId: selected.id,
          content: content.trim(),
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        setError(Array.isArray(data.message) ? data.message.join("，") : data.message || "发送失败");
        return;
      }

      setContent("");
      await loadMessages(selected.id);
      await loadConversations();
    } finally {
      setSending(false);
    }
  }

  async function translateSupportMessage(item: SupportMessage) {
    const existing = translated[item.id];
    if (existing) {
      setTranslated((current) => ({ ...current, [item.id]: "" }));
      return;
    }

    const response = await api("/support/translate", {
      method: "POST",
      body: JSON.stringify({ content: item.content }),
    });
    const data = await response.json();

    if (!response.ok) {
      setError(Array.isArray(data.message) ? data.message.join("，") : data.message || "翻译失败");
      return;
    }

    setTranslated((current) => ({
      ...current,
      [item.id]: data.translatedText || `${data.summary || ""}${data.suggestedReply || ""}` || "翻译结果为空",
    }));
  }

  function logout() {
    localStorage.removeItem("accessToken");
    localStorage.removeItem("supportUser");
    router.push("/login");
  }

  useEffect(() => {
    const token = localStorage.getItem("accessToken");
    if (!token) {
      router.push("/login");
      return;
    }

    loadConversations();
  }, []);

  return (
    <main className="h-screen bg-slate-100 flex">
      <aside className="w-96 bg-white border-r border-slate-200 flex flex-col">
        <header className="h-16 border-b border-slate-200 px-5 flex items-center justify-between">
          <div>
            <h1 className="font-bold text-slate-900">在线客服</h1>
            <p className="text-xs text-slate-500">客户会话与入金咨询</p>
          </div>
          <button className="text-sm text-slate-500 hover:text-slate-900" onClick={logout}>
            退出
          </button>
        </header>

        {error && <div className="m-3 rounded bg-red-50 px-3 py-2 text-sm text-red-600">{error}</div>}

        <div className="p-3">
          <input
            className="mb-2 w-full rounded border border-slate-300 px-3 py-2 text-sm outline-none focus:border-blue-600"
            placeholder="搜索客户、手机号、编号、标签或消息"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
          />
          <button
            className="w-full rounded border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50"
            onClick={loadConversations}
            disabled={loading}
          >
            {loading ? "刷新中..." : "刷新会话"}
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-3 pb-3">
          {filteredConversations.length === 0 && (
            <div className="rounded border border-dashed border-slate-300 p-6 text-center text-sm text-slate-500">
              暂无会话
            </div>
          )}

          {filteredConversations.map((conversation) => (
            <button
              key={conversation.id}
              onClick={() => {
                setSelected(conversation);
                loadMessages(conversation.id);
              }}
              className={`mb-2 w-full rounded border p-3 text-left ${
                selected?.id === conversation.id
                  ? "border-blue-500 bg-blue-50"
                  : "border-slate-200 bg-white hover:bg-slate-50"
              }`}
            >
              <div className="flex items-center justify-between gap-2">
                <span className="font-medium text-slate-900">
                  {conversation.client?.fullName || "未命名客户"}
                </span>
                {conversation.client?.customerNo && (
                  <span className="rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-600">
                    {conversation.client.customerNo}
                  </span>
                )}
              </div>
              <p className="mt-1 text-xs text-slate-500">
                {conversation.client?.phone ? `+91 ${conversation.client.phone}` : "-"}
              </p>
              <p className="mt-2 truncate text-sm text-slate-600">
                {conversation.messages?.[0]?.content || formatDate(conversation.updatedAt)}
              </p>
              <div className="mt-2 flex flex-wrap gap-1">
                {(conversation.tags || []).map((tag) => (
                  <span key={tag} className="rounded bg-blue-100 px-2 py-0.5 text-xs text-blue-700">
                    {tag}
                  </span>
                ))}
              </div>
            </button>
          ))}
        </div>
      </aside>

      <section className="flex-1 flex flex-col">
        <header className="h-16 bg-white border-b border-slate-200 px-6 flex items-center justify-between">
          <div>
            <h2 className="font-bold text-slate-900">{customerTitle}</h2>
            <p className="text-xs text-slate-500">标签只在客服后台显示，客户不可见</p>
          </div>
          <button
            className="rounded border border-slate-300 px-3 py-2 text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-50"
            disabled={!selected}
            onClick={() => selected && loadMessages(selected.id)}
          >
            刷新消息
          </button>
        </header>

        {selected && (
          <div className="border-b border-slate-200 bg-white px-6 py-4">
            <div className="grid grid-cols-4 gap-3 text-sm">
              <div>
                <p className="text-xs text-slate-500">客户姓名</p>
                <p className="font-medium text-slate-900">{selected.client?.fullName || "未命名客户"}</p>
              </div>
              <div>
                <p className="text-xs text-slate-500">手机号</p>
                <p className="font-medium text-slate-900">
                  {selected.client?.phone ? `+91 ${selected.client.phone}` : "-"}
                </p>
              </div>
              <div>
                <p className="text-xs text-slate-500">客户编号</p>
                <p className="font-medium text-slate-900">{selected.client?.customerNo || "-"}</p>
              </div>
              <div>
                <p className="text-xs text-slate-500">更新时间</p>
                <p className="font-medium text-slate-900">{formatDate(selected.updatedAt)}</p>
              </div>
            </div>

            <div className="mt-4 flex flex-wrap items-center gap-2">
              <span className="text-sm font-medium text-slate-700">内部标签</span>
              {selectedTags.map((tag) => (
                <button
                  key={tag}
                  className={`rounded px-2 py-1 text-xs ${
                    tag === "紧急" ? "bg-red-100 text-red-700" : "bg-blue-100 text-blue-700"
                  }`}
                  onClick={() => removeTag(tag)}
                  title="点击移除标签"
                >
                  {tag} ×
                </button>
              ))}
              {presetTags
                .filter((tag) => !selectedTags.includes(tag))
                .map((tag) => (
                  <button
                    key={tag}
                    className="rounded border border-slate-300 px-2 py-1 text-xs text-slate-600 hover:bg-slate-50"
                    onClick={() => addTag(tag)}
                  >
                    + {tag}
                  </button>
                ))}
              <input
                className="w-40 rounded border border-slate-300 px-2 py-1 text-xs outline-none focus:border-blue-600"
                placeholder="自定义备注标签"
                value={tagInput}
                onChange={(event) => setTagInput(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") addTag(tagInput);
                }}
              />
              <button
                className="rounded bg-slate-900 px-2 py-1 text-xs text-white disabled:opacity-50"
                disabled={!tagInput.trim()}
                onClick={() => addTag(tagInput)}
              >
                添加
              </button>
            </div>
          </div>
        )}

        <div className="flex-1 overflow-y-auto p-6 space-y-4">
          {!selected && (
            <div className="h-full flex items-center justify-center text-slate-500">
              请选择左侧客户会话
            </div>
          )}

          {selected &&
            messages.map((item) => {
              const isClient = item.senderType === "CLIENT";
              return (
                <div key={item.id} className={`flex ${isClient ? "justify-start" : "justify-end"}`}>
                  <div
                    className={`max-w-[70%] rounded-lg border px-4 py-3 shadow-sm ${
                      isClient ? "bg-white border-slate-200" : "bg-blue-600 text-white border-blue-600"
                    }`}
                  >
                    <div className="mb-1 text-xs opacity-70">{isClient ? "客户" : "客服"} · {formatDate(item.createdAt)}</div>
                    <p className="whitespace-pre-wrap">{item.content}</p>
                    {item.attachmentUrl && (
                      <a
                        href={item.attachmentUrl}
                        download={item.attachmentName || "attachment"}
                        className={`mt-2 block rounded px-3 py-2 text-sm underline ${isClient ? "bg-slate-100 text-blue-700" : "bg-white/15 text-white"}`}
                      >
                        📎 {item.attachmentName || "查看附件"}
                      </a>
                    )}
                    <div className="mt-2 flex items-center gap-2">
                      <button
                        className={`rounded px-2 py-1 text-xs ${
                          isClient ? "bg-slate-100 text-slate-600" : "bg-blue-500 text-white"
                        }`}
                        onClick={() =>
                          translateSupportMessage(item)
                        }
                      >
                        翻译辅助
                      </button>
                      {isClient && (
                        <button
                          className="rounded bg-slate-100 px-2 py-1 text-xs text-slate-600"
                          onClick={() => setContent(`您好，关于“${item.content.slice(0, 30)}”，我们正在为您核查。`)}
                        >
                          引用回复
                        </button>
                      )}
                    </div>
                    {translated[item.id] && (
                      <p
                        className={`mt-2 rounded px-3 py-2 text-xs ${
                          isClient ? "bg-amber-50 text-amber-700" : "bg-white/15 text-white"
                        }`}
                      >
                        {translated[item.id]}
                      </p>
                    )}
                  </div>
                </div>
              );
            })}
        </div>

        <footer className="bg-white border-t border-slate-200 p-4">
          <div className="mb-3 flex flex-wrap gap-2">
            {quickReplies.map((reply) => (
              <button
                key={reply}
                className="rounded border border-slate-300 px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-50 disabled:opacity-50"
                disabled={!selected}
                onClick={() => setContent(reply)}
              >
                {reply.slice(0, 18)}...
              </button>
            ))}
          </div>
          <div className="flex gap-3">
            <textarea
              className="min-h-16 flex-1 rounded border border-slate-300 px-3 py-2 outline-none focus:border-blue-600 disabled:bg-slate-100"
              placeholder="输入回复内容"
              value={content}
              disabled={!selected}
              onChange={(event) => setContent(event.target.value)}
            />
            <button
              className="rounded bg-blue-600 px-6 font-medium text-white disabled:opacity-50"
              onClick={sendMessage}
              disabled={!selected || sending}
            >
              {sending ? "发送中..." : "发送"}
            </button>
          </div>
        </footer>
      </section>
    </main>
  );
}
