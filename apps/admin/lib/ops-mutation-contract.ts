export type OpsMutationIntent = {
  currentValue: string;
  newValue: string;
  impact: string;
  reason: string;
  requestId: string;
  confirmed: boolean;
};

export type OpsMutationFailureKind =
  | 'denied'
  | 'conflict'
  | 'rate-limited'
  | 'unknown'
  | 'failed';

export type OpsMutationFailure = {
  kind: OpsMutationFailureKind;
  message: string;
  retryable: boolean;
  refreshRequired: boolean;
};

export function validateOpsMutationIntent(intent: OpsMutationIntent) {
  const missing: Array<'impact' | 'reason' | 'requestId' | 'confirmation'> = [];
  if (!intent.impact.trim()) missing.push('impact');
  if (intent.reason.trim().length < 2) missing.push('reason');
  if (!intent.requestId.trim()) missing.push('requestId');
  if (!intent.confirmed) missing.push('confirmation');
  return missing;
}

function numericStatus(error: unknown): number | undefined {
  if (!error || typeof error !== 'object') return undefined;
  const candidate = error as { status?: unknown; response?: { status?: unknown } };
  const value = candidate.status ?? candidate.response?.status;
  return typeof value === 'number' ? value : undefined;
}

export function classifyOpsMutationFailure(error: unknown): OpsMutationFailure {
  const status = numericStatus(error);
  if (status === 401 || status === 403) {
    return {
      kind: 'denied',
      message: '当前账号没有执行此操作的权限。记录未更改。',
      retryable: false,
      refreshRequired: false,
    };
  }
  if (status === 409) {
    return {
      kind: 'conflict',
      message: '记录已发生变化。请刷新确认最新状态后重新操作。',
      retryable: false,
      refreshRequired: true,
    };
  }
  if (status === 429) {
    return {
      kind: 'rate-limited',
      message: '操作过于频繁。请稍后重试；当前结果未被标记为成功。',
      retryable: true,
      refreshRequired: false,
    };
  }
  const code =
    error && typeof error === 'object' && 'code' in error
      ? String((error as { code?: unknown }).code ?? '')
      : '';
  if (code === 'ECONNABORTED' || code === 'ETIMEDOUT') {
    return {
      kind: 'unknown',
      message: '服务器结果暂时未知。请刷新确认记录状态，避免重复提交。',
      retryable: false,
      refreshRequired: true,
    };
  }
  return {
    kind: 'failed',
    message: '操作未完成。记录未被标记为成功，请重试。',
    retryable: true,
    refreshRequired: false,
  };
}
