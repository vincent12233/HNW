"use client";

import { Modal } from "antd";
import type { ModalProps } from "antd";

export default function OpsModal({
  destroyOnHidden = true,
  maskClosable = false,
  mask,
  ...props
}: ModalProps) {
  const maskConfig = {
    closable: maskClosable,
    ...(typeof mask === "object" && mask ? mask : {}),
  };

  return (
    <Modal
      {...props}
      destroyOnHidden={destroyOnHidden}
      mask={mask === false ? false : maskConfig}
      className={["ops-modal", props.className].filter(Boolean).join(" ")}
    />
  );
}
