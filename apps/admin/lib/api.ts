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
