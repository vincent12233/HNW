"use client";

import { GiftOutlined } from "@ant-design/icons";
import { Button, Form, InputNumber, message } from "antd";
import { useRef, useState } from "react";

import OpsModal from "@/components/OpsModal";
import { api } from "@/lib/api";

export default function InvitePoolButton({ id, name }: { id: string; name: string }) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [form] = Form.useForm();
  const busyRef = useRef(false);

  async function generate({ count }: { count: number }) {
    if (busyRef.current) return;
    busyRef.current = true;
    setBusy(true);
    try {
      const result = await api.post(`/business/${id}/invite-codes`, { count });
      message.success(`已为 ${name} 补充 ${result.data.count} 个邀请码`);
      setOpen(false);
    } catch {
      message.error("补充失败，请检查业务员状态后重试");
    } finally {
      busyRef.current = false;
      setBusy(false);
    }
  }

  return (
    <>
      <Button
        icon={<GiftOutlined />}
        aria-label={`为 ${name} 补充邀请码池`}
        onClick={() => {
          form.resetFields();
          setOpen(true);
        }}
      >
        补充邀请码池
      </Button>
      <OpsModal
        title={`${name} · 邀请码池`}
        open={open}
        confirmLoading={busy}
        closable={!busy}
        maskClosable={!busy}
        onCancel={() => {
          if (!busy) setOpen(false);
        }}
        onOk={() => form.submit()}
        okText="确认生成"
        okButtonProps={{ disabled: busy }}
        cancelText="取消"
      >
        <Form form={form} initialValues={{ count: 10 }} layout="vertical" onFinish={(values) => void generate(values)}>
          <Form.Item name="count" label="生成数量" extra="提交后以服务器返回数量为准。" rules={[{ required: true }, { type: "integer", min: 1, max: 100 }]}>
            <InputNumber min={1} max={100} precision={0} disabled={busy} />
          </Form.Item>
        </Form>
      </OpsModal>
    </>
  );
}
