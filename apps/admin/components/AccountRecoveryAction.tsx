"use client";

import { Alert, Button, Card, Checkbox, Input, Select, Space, Typography } from "antd";
import { useCallback, useEffect, useMemo, useState } from "react";

import { api, getApiErrorMessage } from "@/lib/api";
import { maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime } from "@/lib/ops-format";

type Recovery = { id: string; phone: string; status: string; createdAt: string };

export default function AccountRecoveryAction() {
  const [requests, setRequests] = useState<Recovery[]>([]);
  const [selected, setSelected] = useState("");
  const [interactionRef, setInteractionRef] = useState("");
  const [identityVerified, setIdentityVerified] = useState(false);
  const [issuedCode, setIssuedCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    try {
      const response = await api.get<Recovery[]>("/support/recovery");
      setRequests(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "密码找回请求加载失败"));
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const options = useMemo(
    () => requests.map((request) => ({
      value: request.id,
      label: `${maskOpsPhone(request.phone)} / ${request.status === "OPEN" ? "待处理" : "已完成"} / ${formatOpsDateTime(request.createdAt)}`,
      disabled: request.status !== "OPEN",
    })),
    [requests],
  );

  async function issue() {
    if (!selected || busy) return;
    setBusy(true);
    setError("");
    setIssuedCode("");
    try {
      const response = await api.post<{ code?: string }>(
        `/support/recovery/${selected}/issue`,
        { identityVerified, interactionRef: interactionRef.trim() },
      );
      setIssuedCode(String(response.data?.code ?? ""));
      setIdentityVerified(false);
      setInteractionRef("");
      await load();
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "重置码生成失败"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card title="密码找回安全操作" extra={<Typography.Text type="secondary">SaleSmartly interaction reference</Typography.Text>}>
      <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
        <Alert
          type="info"
          showIcon
          message="这里只执行 HNW 密码找回操作，不显示或保存客服聊天记录。"
          description="先在 SaleSmartly 完成客户沟通和独立身份核实，再填写会话参考编号。重置码仅显示一次。"
        />
        <Select
          showSearch
          aria-label="密码找回请求"
          value={selected || undefined}
          placeholder="选择待处理的密码找回请求"
          options={options}
          onChange={(value) => {
            setSelected(value);
            setIssuedCode("");
            setError("");
          }}
          style={{ width: "100%" }}
        />
        <Input
          aria-label="SaleSmartly interaction reference"
          value={interactionRef}
          maxLength={120}
          placeholder="SaleSmartly 会话参考编号"
          onChange={(event) => setInteractionRef(event.target.value)}
        />
        <Checkbox
          checked={identityVerified}
          onChange={(event) => setIdentityVerified(event.target.checked)}
        >
          已在 SaleSmartly 会话外通过独立资料核实客户身份和账号归属
        </Checkbox>
        <Button
          type="primary"
          loading={busy}
          disabled={!selected || !identityVerified || interactionRef.trim().length < 6}
          onClick={() => void issue()}
        >
          生成一次性重置码
        </Button>
        {issuedCode ? (
          <Alert type="warning" showIcon message="一次性重置码（仅显示本次）" description={<Typography.Text copyable code>{issuedCode}</Typography.Text>} />
        ) : null}
        {error ? <Alert role="alert" type="error" showIcon message={error} /> : null}
      </Space>
    </Card>
  );
}
