"use client";

import { Drawer } from "antd";
import type { DrawerProps } from "antd";

export default function OpsDrawer({
  width = 480,
  size,
  destroyOnHidden = true,
  className,
  ...props
}: DrawerProps) {
  return (
    <Drawer
      {...props}
      size={size ?? width}
      destroyOnHidden={destroyOnHidden}
      className={["ops-drawer", className].filter(Boolean).join(" ")}
    />
  );
}
