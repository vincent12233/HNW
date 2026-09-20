"use client";

import { Modal } from "antd";
import type { ModalProps } from "antd";

export default function OpsModal({
  destroyOnHidden = true,
  maskClosable = false,
  ...props
}: ModalProps) {
  return (
    <Modal
      {...props}
      destroyOnHidden={destroyOnHidden}
      maskClosable={maskClosable}
      className={["ops-modal", props.className].filter(Boolean).join(" ")}
    />
  );
}
