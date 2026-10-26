import ws from 'k6/ws';
import { check } from 'k6';

const socketUrl = __ENV.WS_URL || 'ws://localhost:3000/socket.io/?EIO=4&transport=websocket';

export const options = {
  scenarios: {
    normal_connections: { executor: 'constant-vus', vus: 20, duration: '2m' },
    reconnect_storm: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { target: 100, duration: '20s' },
        { target: 100, duration: '30s' },
        { target: 0, duration: '20s' },
      ],
    },
  },
  thresholds: { checks: ['rate>0.99'], ws_connecting: ['p(95)<1000'] },
};

export default function () {
  const response = ws.connect(socketUrl, {}, (socket) => {
    socket.on('open', () => socket.send('40'));
    socket.on('message', (message) => {
      check(message, { 'socket payload is bounded': (value) => value.length < 1048576 });
    });
    socket.setTimeout(() => socket.close(), 5000);
  });
  check(response, { 'websocket upgrade succeeded': (r) => r && r.status === 101 });
}
