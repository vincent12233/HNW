"use client";
import { useRef, useState } from "react";
import { Button, Form, Input, Modal, Select, message } from "antd";
import { EditOutlined } from "@ant-design/icons";
import { api } from "@/lib/api";

type Props = { name: string; endpoint: string; kind: "status" | "active" | "password" | "tier";
  current?: string; onSaved: () => void };
export default function ScopedEditButton({ name, endpoint, kind, current, onSaved }: Props) {
  const [open, setOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const savingRef = useRef(false);
  const [form] = Form.useForm();
  const title = kind === "tier" ? "修改会员等级" : kind === "password" ? "重置登录密码" : "修改账户状态";
  async function save(values: { status?: string; newPassword?: string; tier?: string }) {
    if (savingRef.current) return;
    savingRef.current = true;
    setSaving(true);
    try {
      const payload = kind === "active" ? { isActive: values.status === "ACTIVE" }
        : kind === "tier" ? { tier: values.tier }
        : kind === "password" ? { newPassword: values.newPassword }
        : { status: values.status };
      await api.patch(endpoint, payload);
    } catch { message.error("保存失败，请检查权限或刷新后重试"); return; }
    finally { savingRef.current = false; setSaving(false); }
    message.success("修改已保存");
    setOpen(false);
    form.resetFields();
    try { await onSaved(); }
    catch { message.warning("修改已保存，但列表刷新失败，请刷新页面查看最新数据"); }
  }
  return <>
    <Button size="small" disabled={saving} icon={<EditOutlined />} onClick={() => {
      if (savingRef.current) return;
      form.resetFields(); form.setFieldsValue({ status: current, tier: current }); setOpen(true);
    }}>{title}</Button>
    <Modal title={title} open={open} confirmLoading={saving} okText="确认保存" cancelText="取消"
      onOk={() => { if (!savingRef.current) form.submit(); }} onCancel={() => { if (!savingRef.current) setOpen(false); }}
      closable={!saving} maskClosable={!saving} cancelButtonProps={{ disabled: saving }}>
      <p>{name}</p>
      <Form form={form} layout="vertical" onFinish={save}>
        {kind === "tier" ? <Form.Item name="tier" label="会员等级" rules={[{ required: true }]}>
          <Select disabled={saving} options={[
            { value: 'STANDARD', label: '标准 Standard' }, { value: 'SILVER', label: '白银 Silver' },
            { value: 'GOLD', label: '黄金 Gold' }, { value: 'PLATINUM', label: '铂金 Platinum' },
          ]} />
        </Form.Item> : kind === "password" ? <Form.Item name="newPassword" label="新登录密码"
          rules={[{ required: true }, { min: 12, max: 72, message: "密码长度为 12–72 位" }]}>
          <Input.Password autoComplete="new-password" disabled={saving} />
        </Form.Item> : <Form.Item name="status" label="账户状态" rules={[{ required: true }]}>
          <Select disabled={saving} options={[
            { value: "ACTIVE", label: "正常" }, { value: "SUSPENDED", label: "暂停" },
            ...(kind === "status" ? [{ value: "DISABLED", label: "停用" }] : []),
          ]} />
        </Form.Item>}
      </Form>
    </Modal>
  </>;
}
