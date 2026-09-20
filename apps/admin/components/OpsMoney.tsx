"use client";

import { formatInr } from "@/lib/ops-format";

type Props = {
  value?: string | number | null;
  empty?: string;
};

export default function OpsMoney({ value, empty }: Props) {
  return (
    <span className="ops-money" title={formatInr(value, empty)}>
      {formatInr(value, empty)}
    </span>
  );
}
