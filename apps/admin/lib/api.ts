import axios from 'axios';
import { getBackendRole } from './backend-role';

const configuredApiUrl = process.env.NEXT_PUBLIC_API_URL?.trim();
const isLoopbackHttp = !!configuredApiUrl && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(configuredApiUrl);
const isPrivateLanHttp = !!configuredApiUrl && /^http:\/\/(?:10\.(?:\d{1,3}\.){2}\d{1,3}|192\.168\.(?:\d{1,3}\.)?\d{1,3}|172\.(?:1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})(:\d+)?$/i.test(configuredApiUrl);
if (process.env.NODE_ENV === 'production' && (!configuredApiUrl || (!configuredApiUrl.startsWith('https://') && !isLoopbackHttp && !isPrivateLanHttp))) {
  throw new Error('NEXT_PUBLIC_API_URL must be an HTTPS URL in production');
}
const API_URL = configuredApiUrl || 'http://localhost:3000';

export const api = axios.create({
  baseURL: API_URL,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use((config) => {
  const role = getBackendRole();
  if (role) {
    config.headers.set('X-Backend-Role', role);
  }
  return config;
});

api.interceptors.response.use(
  (response) => {
    const method = response.config.method?.toLowerCase();
    if (typeof window !== 'undefined' && method && ['post', 'put', 'patch', 'delete'].includes(method)) {
      window.dispatchEvent(new CustomEvent('admin-data-changed'));
    }
    return response;
  },
  (error) => {
    if (typeof window !== 'undefined' && error?.response?.status === 401 && window.location.pathname !== '/login') {
      localStorage.removeItem('adminUser');
      window.location.replace('/login');
    }
    return Promise.reject(error);
  },
);

const OTC_ERROR_ZH: Record<string, string> = {
  'Valid offer period is required': '请填写有效的上架时间',
  'Valid settlement price is required': '请填写有效的折扣结算价',
  'Valid price and offer period are required':
    '请填写有效的折扣结算价与上架时间',
  'Active instrument not found': '未找到可用股票',
  'A live market quote is required before publishing': '上架前需要有效的实时行情',
  'A live market quote is required before updating settlement price':
    '更新折扣结算价前需要有效的实时行情',
  'Settlement price cannot exceed the live market quote':
    '折扣结算价不能高于实时行情',
  'This OTC stock is already listed; edit the existing offer instead':
    '该股票已上架 OTC，请使用「编辑」修改，勿重复上架',
  'OTC offer not found': '未找到 OTC 上架记录',
  'OTC offer is not active': '该 OTC 上架已下架或不可用',
  'OTC order not found': '未找到 OTC 订单',
  'OTC order already reviewed': '该 OTC 订单已审核',
  'Insufficient buying power or available cash balance':
    '客户可用资金或购买力不足，无法完成结算',
  'OTC order is not assigned to this business account':
    '该 OTC 订单不在当前业务员名下',
  'OTC order is outside the dedicated operator scope':
    '该 OTC 订单不在当前专用运营范围内',
  'Provide issuePrice and/or openDate/closeDate to update':
    '请提供申购价和/或申购期间',
  'IPO pricing can only be edited while DRAFT or before any applications':
    '仅草稿或尚无申购时可修改申购价',
  'IPO pricing cannot be edited after close, listing, or allotment':
    '已下架、上市或分配完成后不可修改申购价',
  'openDate must be earlier than closeDate': '申购开始时间须早于结束时间',
  'IPO not found': '未找到 IPO',
};

const OTC_ERROR_ZH_PREFIX: Array<[string, string]> = [
  [
    'Allocation exceeds remaining IPO shares',
    '分配数量超过剩余可分配股数',
  ],
  [
    'Insufficient IPO shares remaining for this allotment',
    '剩余可分配股数不足，无法公布该分配',
  ],
];

/** Map a Nest error message string (exact or known prefix) to Chinese when possible. */
export function mapApiErrorText(text: string): string {
  if (OTC_ERROR_ZH[text]) return OTC_ERROR_ZH[text];
  for (const [prefix, zh] of OTC_ERROR_ZH_PREFIX) {
    if (text.startsWith(prefix)) return zh;
  }
  return text;
}

/** Prefer Nest `message`, with known OTC/IPO English strings mapped to Chinese. */
export function getApiErrorMessage(error: unknown, fallback: string): string {
  const raw = (error as { response?: { data?: { message?: unknown } } })
    ?.response?.data?.message;
  const text = Array.isArray(raw)
    ? raw.map(String).join('；')
    : raw == null
      ? ''
      : String(raw);
  if (!text) return fallback;
  return mapApiErrorText(text);
}
