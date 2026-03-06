/**
 * k6 Load Test — Health + Status endpoints
 *
 * Smoke test for public endpoints under high concurrency.
 *
 * Usage:
 *   k6 run --env BASE_URL=http://localhost:4000 k6/health_load.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 100 },
    { duration: '30s', target: 200 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';

export default function () {
  const res = http.get(`${BASE_URL}/health`);

  check(res, {
    'health returns 200': (r) => r.status === 200,
    'status is healthy or degraded': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status === 'healthy' || body.status === 'degraded';
      } catch {
        return false;
      }
    },
  });

  sleep(0.05);
}
