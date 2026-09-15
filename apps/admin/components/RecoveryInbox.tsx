"use client";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";

type Recovery = { id: string; phone: string; status: string; createdAt: string };
type Message = { id: string; sender: string; content: string };

async function request<T>(path: string, body?: object): Promise<T> {
  const response = body ? await api.post<T>(path, body) : await api.get<T>(path);
  return response.data;
}

export default function RecoveryInbox() {
  const [requests, setRequests] = useState<Recovery[]>([]);
  const [selected, setSelected] = useState("");
  const [messages, setMessages] = useState<Message[]>([]);
  const [content, setContent] = useState("");
  const [verified, setVerified] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        const data = await request<Recovery[]>("/support/recovery");
        if (active) setRequests(data);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "加载失败");
      }
    };
    void load();
    const timer = setInterval(load, 10000);
    return () => {
      active = false;
      clearInterval(timer);
    };
  }, []);

  useEffect(() => {
    if (!selected) return;
    let active = true;
    const load = async () => {
      try {
        const data = await request<Message[]>(
          `/support/recovery/${selected}/messages`,
        );
        if (active) setMessages(data);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "加载失败");
      }
    };
    void load();
    const timer = setInterval(load, 5000);
    return () => {
      active = false;
      clearInterval(timer);
    };
  }, [selected]);

  const current = requests.find((r) => r.id === selected);

  function selectSession(id: string) {
    setSelected(id);
    setVerified(false);
    setMessages([]);
    setContent("");
    setError("");
  }

  async function action(issue: boolean) {
    if (!selected || busy) return;
    setBusy(true);
    setError("");
    try {
      await request(
        `/support/recovery/${selected}/${issue ? "issue" : "messages"}`,
        issue ? { identityVerified: verified } : { content },
      );
      setContent("");
      setVerified(false);
      setMessages(
        await request<Message[]>(`/support/recovery/${selected}/messages`),
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "操作失败");
    } finally {
      setBusy(false);
    }
  }

  return (
    <details
      style={{
        background: "white",
        borderBottom: "1px solid #e5e7eb",
        padding: 16,
      }}
    >
      <summary style={{ cursor: "pointer", fontWeight: 600 }}>
        密码找回客服 ({requests.filter((r) => r.status === "OPEN").length})
      </summary>
      <div style={{ display: "grid", gap: 12, paddingTop: 12 }}>
        <select
          aria-label="密码找回会话"
          value={selected}
          disabled={busy}
          onChange={(e) => selectSession(e.target.value)}
          style={{ padding: 10, border: "1px solid #d1d5db" }}
        >
          <option value="">选择客户找回密码会话</option>
          {requests.map((r) => (
            <option key={r.id} value={r.id}>
              {r.phone.startsWith("+") ? r.phone : `+91 ${r.phone}`} /{" "}
              {r.status === "OPEN" ? "待处理" : "已完成"} /{" "}
              {new Date(r.createdAt).toLocaleString()}
            </option>
          ))}
        </select>
        {selected && (
          <>
            <div
              style={{
                maxHeight: 280,
                minHeight: 70,
                overflowY: "auto",
                padding: 12,
                background: "#f7f8fa",
              }}
            >
              {messages.length === 0 && <p>暂无消息，客户正在等待客服。</p>}
              {messages.map((m) => (
                <p
                  key={m.id}
                  style={{
                    marginBottom: 10,
                    whiteSpace: "pre-wrap",
                    overflowWrap: "anywhere",
                  }}
                >
                  <strong>{m.sender === "CLIENT" ? "客户" : "客服"}：</strong>
                  {m.content}
                </p>
              ))}
            </div>
            {current?.status === "OPEN" && (
              <>
                <textarea
                  aria-label="客服回复"
                  placeholder="回复客户"
                  maxLength={2000}
                  value={content}
                  onChange={(e) => setContent(e.target.value)}
                  style={{ padding: 10, border: "1px solid #d1d5db" }}
                />
                <button
                  disabled={busy || !content.trim()}
                  onClick={() => action(false)}
                  style={{
                    padding: 10,
                    color: "white",
                    background: "#0055f5",
                    borderRadius: 4,
                  }}
                >
                  发送回复
                </button>
                <label
                  style={{ display: "flex", gap: 8, alignItems: "center" }}
                >
                  <input
                    type="checkbox"
                    checked={verified}
                    disabled={busy}
                    onChange={(e) => setVerified(e.target.checked)}
                  />
                  已通过独立资料核实客户身份和账号归属
                </label>
                <button
                  disabled={busy || !verified}
                  onClick={() => action(true)}
                  style={{
                    padding: 10,
                    border: "1px solid #d1d5db",
                    borderRadius: 4,
                  }}
                >
                  生成并发送重置码
                </button>
              </>
            )}
          </>
        )}
        {error && (
          <p role="alert" style={{ color: "#c62828" }}>
            {error}
          </p>
        )}
      </div>
    </details>
  );
}
