import { resolve } from "node:path";
import { Client } from "pg";
import { PostgreSqlContainer, StartedPostgreSqlContainer } from "@testcontainers/postgresql";

const tenantA = "a9c76aa8-6d5d-4a8a-8f04-c0b42970e001";
const tenantB = "b8a7365d-130d-45c1-9758-0d909bb4b002";
const actorId = "c2211658-65c4-42f1-9b19-21fb3e579003";

describe("PostgreSQL tenant boundaries and audit trail", () => {
  let container: StartedPostgreSqlContainer;
  let owner: Client;
  let runtime: Client;
  let insertedUserId: string;

  beforeAll(async () => {
    const migration = resolve(__dirname, "../../../infra/docker/postgres/init/001_core.sql");
    container = await new PostgreSqlContainer("postgres:17-alpine")
      .withDatabase("th7_enterprise_suite_test")
      .withUsername("th7_test_owner")
      .withPassword("test-owner-password")
      .withInitScripts(migration)
      .start();

    owner = new Client({ connectionString: container.getConnectionUri() });
    await owner.connect();
    await owner.query("CREATE ROLE th7_test_runtime LOGIN PASSWORD 'test-runtime-password' NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS");
    await owner.query("GRANT CONNECT ON DATABASE th7_enterprise_suite_test TO th7_test_runtime");
    await owner.query("GRANT USAGE ON SCHEMA public, app TO th7_test_runtime");
    await owner.query("GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO th7_test_runtime");
    await owner.query("GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO th7_test_runtime");

    await owner.query(
      "INSERT INTO tenants (id, slug, display_name) VALUES ($1, 'tenant-a', 'Tenant A'), ($2, 'tenant-b', 'Tenant B')",
      [tenantA, tenantB],
    );

    runtime = new Client({
      connectionString: container.getConnectionUri().replace("th7_test_owner:test-owner-password", "th7_test_runtime:test-runtime-password"),
    });
    await runtime.connect();

    await runtime.query("BEGIN");
    await setTenant(tenantA);
    await runtime.query("SELECT set_config('app.actor_id', $1, true)", [actorId]);
    await runtime.query("SELECT set_config('app.client_ip', '203.0.113.8', true)");
    await runtime.query("SELECT set_config('app.device_info', 'integration-test', true)");
    const inserted = await runtime.query(
      "INSERT INTO users (tenant_id, email, display_name, password_hash) VALUES ($1, 'owner@example.test', 'Tenant A user', 'hash-must-not-be-audited') RETURNING id",
      [tenantA],
    );
    const insertedRow = inserted.rows.at(0);
    if (!insertedRow) {
      throw new Error("The tenant user insert returned no row");
    }
    insertedUserId = insertedRow.id as string;
    await runtime.query("COMMIT");
  });

  afterAll(async () => {
    await runtime?.end();
    await owner?.end();
    await container?.stop();
  });

  it("does not return another tenant's rows, even when queried by its identifier", async () => {
    await runtime.query("BEGIN");
    await setTenant(tenantA);
    const result = await runtime.query("SELECT id FROM tenants WHERE id = $1", [tenantB]);
    expect(result.rowCount).toBe(0);
    await runtime.query("ROLLBACK");
  });

  it("resets the tenant setting at transaction end on a reused connection", async () => {
    await runtime.query("BEGIN");
    await setTenant(tenantA);
    expect((await runtime.query("SELECT id FROM tenants")).rowCount).toBe(1);
    await runtime.query("COMMIT");
    expect((await runtime.query("SELECT id FROM tenants")).rowCount).toBe(0);
  });

  it("records actor and device context but redacts password hashes", async () => {
    await runtime.query("BEGIN");
    await setTenant(tenantA);
    const result = await runtime.query(
      "SELECT actor_id::text, ip_address::text, device_info, new_value FROM audit_logs WHERE tenant_id = $1 AND entity_id = $2",
      [tenantA, insertedUserId],
    );
    const audit = result.rows.at(0);
    expect(audit).toBeDefined();
    if (!audit) {
      throw new Error("The user audit record was not found");
    }
    expect(audit).toMatchObject({
      actor_id: actorId,
      ip_address: "203.0.113.8",
      device_info: "integration-test",
    });
    expect(audit.new_value.password_hash).toBeUndefined();
    expect(audit.new_value.display_name).toBe("Tenant A user");
    await runtime.query("ROLLBACK");
  });

  it("rejects hard deletes for tenant data", async () => {
    await runtime.query("BEGIN");
    await setTenant(tenantA);
    await expect(runtime.query("DELETE FROM users WHERE tenant_id = $1 AND id = $2", [tenantA, insertedUserId]))
      .rejects.toThrow("Hard deletes are prohibited");
    await runtime.query("ROLLBACK");
  });

  it("rejects mutation of audit history", async () => {
    await runtime.query("BEGIN");
    await setTenant(tenantA);
    await expect(
      runtime.query("UPDATE audit_logs SET device_info = 'tampered' WHERE tenant_id = $1 AND entity_id = $2", [tenantA, insertedUserId]),
    ).rejects.toThrow("Audit records are immutable");
    await runtime.query("ROLLBACK");
  });

  async function setTenant(tenantId: string): Promise<void> {
    await runtime.query("SELECT set_config('app.tenant_id', $1, true)", [tenantId]);
  }
});