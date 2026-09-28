import http from "k6/http";
import { check } from "k6";

const baseUrl = __ENV.AUTH_BASE_URL || "http://127.0.0.1:3001";

export const options = {
  stages: [
    { duration: "15s", target: 5 },
    { duration: "30s", target: 5 },
    { duration: "10s", target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<250"],
  },
};

export default function () {
  const response = http.get(`${baseUrl}/api/v1/health`);
  check(response, {
    "health route returns 200": (result) => result.status === 200,
    "health payload identifies auth": (result) => result.json("service") === "auth",
  });
}