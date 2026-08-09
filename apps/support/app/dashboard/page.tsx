"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { api } from "@/lib/api";

type Conversation = {
  id: string;
  tags?: string[];
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
};

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function Dashboard() {
  const router = useRouter();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selected, setSelected] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [content, setContent] = useState("");
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");

  const customerTitle = useMemo(() => {
    if (!selected) return "请选择客户会话";
    const name = selected.client?.fullName || "未命名客户";
    const phone = selected.client?.phone ? `+91 ${selected.client.phone}` : "-";
    return `${name} / ${phone}`;
  }, [selected]);

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
          <button
            className="w-full rounded border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50"
            onClick={loadConversations}
            disabled={loading}
          >
            {loading ? "刷新中..." : "刷新会话"}
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-3 pb-3">
          {conversations.length === 0 && (
            <div className="rounded border border-dashed border-slate-300 p-6 text-center text-sm text-slate-500">
              暂无会话
            </div>
          )}

          {conversations.map((conversation) => (
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
        </header>

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
                  </div>
                </div>
              );
            })}
        </div>

        <footer className="bg-white border-t border-slate-200 p-4">
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
