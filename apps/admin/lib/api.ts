import axios from 'axios';
import { getBackendRole } from './backend-role';

const configuredApiUrl = process.env.NEXT_PUBLIC_API_URL?.trim();
const isLoopbackHttp = !!configuredApiUrl && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(configuredApiUrl);
if (process.env.NODE_ENV === 'production' && (!configuredApiUrl || (!configuredApiUrl.startsWith('https://') && !isLoopbackHttp))) {
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
