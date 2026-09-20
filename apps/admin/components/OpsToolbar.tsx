"use client";

import type { ReactNode } from "react";

type Props = {
  children: ReactNode;
  extra?: ReactNode;
};

/** Filter / search strip. Visual only. */
export default function OpsToolbar({ children, extra }: Props) {
  return (
    <div className="ops-toolbar" role="search">
      <div className="ops-toolbar-filters">{children}</div>
      {extra ? <div className="ops-toolbar-extra">{extra}</div> : null}
    </div>
  );
}
