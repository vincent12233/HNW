"use client";

import { GiftOutlined } from "@ant-design/icons";
import { Button, Form, InputNumber, Modal, message } from "antd";
import { useState } from "react";
import { api } from "@/lib/api";

export default function InvitePoolButton({ id, name }: { id: string; name: string }) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [form] = Form.useForm();
  async function generate({ count }: { count: number }) {
    setBusy(true);
    try {
      const result = await api.post(`/business/${id}/invite-codes`, { count });
      message.success(`已为 ${name} 补充 ${result.data.count} 个邀请码`);
      setOpen(false);
    } catch {
      message.error("补充失败，请检查业务员状态后重试");
    } finally { setBusy(false); }
  }
  return <>
    <Button icon={<GiftOutlined />} onClick={() => { form.resetFields(); setOpen(true); }}>补充邀请码池</Button>
    <Modal title={`${name} · 邀请码池`} open={open} confirmLoading={busy} closable={!busy} maskClosable={!busy}
      onCancel={() => { if (!busy) setOpen(false); }} onOk={() => form.submit()} okText="生成" cancelText="取消">
      <Form form={form} initialValues={{ count: 10 }} layout="vertical" onFinish={generate}>
        <Form.Item name="count" label="生成数量" rules={[{ required: true }, { type: "integer", min: 1, max: 100 }]}>
          <InputNumber min={1} max={100} precision={0} disabled={busy} />
        </Form.Item>
      </Form>
    </Modal>
  </>;
}
