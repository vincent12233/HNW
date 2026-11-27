// Retain an ambiguous operation across modal close/reload; only a confirmed reply clears it.
export type PendingRepayment = { requestId: string; amount: string; note: string };
export function repaymentOperation(storage: Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>, loanId: string) {
  const key = `hnw:pending-loan-repayment:${loanId}`;
  return {
    read(): PendingRepayment | null {
      const saved = storage.getItem(key);
      return saved ? JSON.parse(saved) as PendingRepayment : null;
    },
    begin(amount: string, note: string): PendingRepayment {
      const prior = this.read();
      if (prior) {
        if (prior.amount !== amount || prior.note !== note) throw new Error('请先重试并确认上次还款结果');
        return prior;
      }
      const pending = { requestId: crypto.randomUUID(), amount, note };
      storage.setItem(key, JSON.stringify(pending));
      return pending;
    },
    complete() { storage.removeItem(key); },
  };
}
