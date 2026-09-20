"use client";

import { Drawer } from "antd";
import type { DrawerProps } from "antd";

export default function OpsDrawer({
  width = 480,
  destroyOnHidden = true,
  className,
  ...props
}: DrawerProps) {
  return (
    <Drawer
      {...props}
      width={width}
      destroyOnHidden={destroyOnHidden}
      className={["ops-drawer", className].filter(Boolean).join(" ")}
    />
  );
}
