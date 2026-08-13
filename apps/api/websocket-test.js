const { io } = require('socket.io-client');

const apiUrl = process.env.API_BASE_URL || 'http://localhost:3000';

const socket = io(apiUrl, {
  transports: ['websocket'],
});

socket.on('connect', () => {
  console.log('WebSocket connected', socket.id, apiUrl);
});

socket.on('market-update', (data) => {
  console.log('MARKET UPDATE:', data);
});

socket.on('disconnect', () => {
  console.log('Disconnected');
});

socket.on('connect_error', (error) => {
  console.error('Connection error:', error.message);
});
