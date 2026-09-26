import { AsyncLocalStorage } from 'node:async_hooks';

interface RequestContextValue {
  requestId: string;
}

const storage = new AsyncLocalStorage<RequestContextValue>();

export function runWithRequestContext<T>(requestId: string, callback: () => T) {
  return storage.run({ requestId }, callback);
}

export function currentRequestId() {
  return storage.getStore()?.requestId;
}
