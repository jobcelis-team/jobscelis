/**
 * k6 Load Test — Event Ingestion
 *
 * Tests the POST /api/v1/events endpoint under load.
 *
 * Usage:
 *   k6 run --env API_KEY=your_api_key --env BASE_URL=http://localhost:4000 k6/events_load.js
 *
 * Stages:
 *   1. Ramp up to 50 VUs over 30s
 *   2. Sustain 100 VUs for 1 minute
 *   3. Peak at 200 VUs for 30s
 *   4. Ramp down to 0 over 30s
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const eventLatency = new Trend('event_creation_latency');

export const options = {
  stages: [
    { duration: '30s', target: 50 },
    { duration: '1m', target: 100 },
    { duration: '30s', target: 200 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    errors: ['rate<0.05'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const API_KEY = __ENV.API_KEY;

const topics = [
  'order.created',
  'order.updated',
  'payment.received',
  'user.signup',
  'invoice.generated',
];

export default function () {
  const topic = topics[Math.floor(Math.random() * topics.length)];

  const payload = JSON.stringify({
    topic: topic,
    payload: {
      timestamp: new Date().toISOString(),
      vu: __VU,
      iter: __ITER,
      amount: Math.floor(Math.random() * 10000) / 100,
    },
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-Api-Key': API_KEY,
    },
  };

  const res = http.post(`${BASE_URL}/api/v1/events`, payload, params);

  eventLatency.add(res.timings.duration);

  const success = check(res, {
    'status is 201': (r) => r.status === 201,
    'has event id': (r) => {
      try {
        return JSON.parse(r.body).data.id !== undefined;
      } catch {
        return false;
      }
    },
  });

  errorRate.add(!success);
  sleep(0.1);
}
