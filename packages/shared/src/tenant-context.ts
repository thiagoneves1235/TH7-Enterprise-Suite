import { AsyncLocalStorage } from "node:async_hooks";

export interface TenantContextValue {
  readonly tenantId: string;
  readonly actorId?: string;
  readonly requestId: string;
}

const contextStorage = new AsyncLocalStorage<TenantContextValue>();
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class TenantContext {
  static run<T>(value: TenantContextValue, callback: () => T): T {
    if (!uuidPattern.test(value.tenantId)) {
      throw new TypeError("tenantId must be a UUID");
    }
    if (!value.requestId.trim()) {
      throw new TypeError("requestId must not be empty");
    }
    return contextStorage.run(Object.freeze({ ...value }), callback);
  }

  static current(): TenantContextValue {
    const value = contextStorage.getStore();
    if (!value) {
      throw new Error("Tenant context is not available");
    }
    return value;
  }
}