"use client";

import { CopyOutlined, ReloadOutlined } from "@ant-design/icons";
import { Alert, Button, Space, Tooltip, Typography, message } from "antd";
import { useCallback, useEffect, useRef, useState } from "react";
import { api } from "@/lib/api";

type Invite = { id: string; code: string; expiresAt: string | null };
export default function CurrentInviteCode() {
  const [code, setCode] = useState<Invite | null>(null);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState(false);
  const pending = useRef(false);
  const load = useCallback(async (previousId?: string) => {
    if (pending.current) return;
    pending.current = true;
    setBusy(true); setError(false); setCode(null);
    try { setCode((await api.get<{ code: Invite | null }>("/business/my-invite-code", { params: { previousId } })).data.code); }
    catch { setError(true); }
    finally { pending.current = false; setBusy(false); }
  }, []);
  useEffect(() => { void load(); }, [load]);
  return <section style={{ border: "1px solid #e8edf5", borderRadius: 8, padding: 20, height: "100%" }}>
    <Typography.Text type="secondary">客户注册邀请码</Typography.Text>
    <Space wrap style={{ display: "flex", marginTop: 12 }}>
      <Typography.Text strong style={{ fontSize: 20 }}>{busy ? "加载中…" : code?.code ?? "暂无可用邀请码"}</Typography.Text>
      <Tooltip title="复制邀请码"><Button aria-label="复制邀请码" icon={<CopyOutlined />} disabled={!code || busy} onClick={async () => {
        try { await navigator.clipboard.writeText(code!.code); message.success("已复制"); }
        catch { message.error("复制失败，请重试"); }
      }} /></Tooltip>
      <Tooltip title="刷新邀请码"><Button aria-label="刷新邀请码" icon={<ReloadOutlined />} loading={busy} onClick={() => void load(code?.id)} /></Tooltip>
    </Space>
    {error && <Alert type="error" title="邀请码加载失败，请刷新重试" />}
    {!busy && !error && !code && <Typography.Text type="secondary">请联系管理员补充邀请码池</Typography.Text>}
  </section>;
}
