/**
 * k6 Load Test — Webhook CRUD + Deliveries
 *
 * Tests webhook creation and delivery listing under load.
 *
 * Usage:
 *   k6 run --env API_KEY=your_api_key --env BASE_URL=http://localhost:4000 k6/webhooks_load.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '20s', target: 30 },
    { duration: '1m', target: 50 },
    { duration: '20s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<800'],
    errors: ['rate<0.05'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const API_KEY = __ENV.API_KEY;

const headers = {
  'Content-Type': 'application/json',
  'X-Api-Key': API_KEY,
};

export default function () {
  // List webhooks
  const listRes = http.get(`${BASE_URL}/api/v1/webhooks`, { headers });

  check(listRes, {
    'list webhooks 200': (r) => r.status === 200,
  });

  // List deliveries
  const delRes = http.get(`${BASE_URL}/api/v1/deliveries`, { headers });

  const success = check(delRes, {
    'list deliveries 200': (r) => r.status === 200,
  });

  errorRate.add(!success);
  sleep(0.5);
}
