import { HealthController } from "../src/health.controller";

describe("HealthController", () => {
  it("identifies the service without exposing dependency readiness", () => {
    expect(new HealthController().getHealth()).toEqual({ status: "ok", service: "auth" });
  });
});