import axios from 'axios';

const configuredApiUrl = process.env.NEXT_PUBLIC_API_URL?.trim();
if (process.env.NODE_ENV === 'production' && (!configuredApiUrl || !configuredApiUrl.startsWith('https://'))) {
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
