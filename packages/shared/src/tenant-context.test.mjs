import assert from "node:assert/strict";
import test from "node:test";
import { TenantContext } from "../dist/tenant-context.js";

const tenantId = "8235d4f1-65c2-4c28-a49a-e34718d6e37a";

test("tenant context is available inside its asynchronous scope", async () => {
  const value = { tenantId, actorId: "f48de6e0-cb79-463e-8bc5-98ddaa03bd44", requestId: "request-1" };
  const result = await TenantContext.run(value, async () => {
    await Promise.resolve();
    return TenantContext.current();
  });
  assert.deepEqual(result, value);
});

test("tenant context does not leak across concurrent scopes", async () => {
  const tenants = [tenantId, "e4c1f3a0-9b75-4c6f-a4b2-b873f6e1c5d0"];
  const results = await Promise.all(tenants.map((id) =>
    TenantContext.run({ tenantId: id, requestId: id }, async () => {
      await new Promise((resolve) => setImmediate(resolve));
      return TenantContext.current().tenantId;
    }),
  ));
  assert.deepEqual(results, tenants);
});

test("invalid tenant identifiers and missing scopes fail closed", () => {
  assert.throws(() => TenantContext.run({ tenantId: "tenant-a", requestId: "request-1" }, () => null), /UUID/);
  assert.throws(() => TenantContext.current(), /not available/);
});