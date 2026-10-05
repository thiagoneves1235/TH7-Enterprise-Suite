BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS app;

CREATE FUNCTION app.current_tenant_id() RETURNS uuid
LANGUAGE sql STABLE PARALLEL SAFE
AS $$ SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid $$;

CREATE FUNCTION app.audit_redacted(value jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$ SELECT value - ARRAY['password_hash', 'mfa_secret', 'refresh_token_hash', 'secret_hash', 'access_token'] $$;

CREATE FUNCTION app.write_audit_log() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  tenant_key uuid;
  actor_key uuid;
  old_row jsonb;
  new_row jsonb;
BEGIN
  IF TG_OP = 'UPDATE' THEN old_row := to_jsonb(OLD); END IF;
  new_row := to_jsonb(NEW);
  tenant_key := COALESCE((new_row ->> 'tenant_id')::uuid, (old_row ->> 'tenant_id')::uuid);
  actor_key := NULLIF(current_setting('app.actor_id', true), '')::uuid;
  INSERT INTO public.audit_logs (
    tenant_id, actor_id, action, entity_type, entity_id,
    previous_value, new_value, ip_address, device_info, occurred_at
  ) VALUES (
    tenant_key,
    actor_key,
    TG_OP,
    TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
    COALESCE((new_row ->> 'id')::uuid, (old_row ->> 'id')::uuid),
    app.audit_redacted(old_row),
    app.audit_redacted(new_row),
    NULLIF(current_setting('app.client_ip', true), '')::inet,
    NULLIF(current_setting('app.device_info', true), ''),
    clock_timestamp()
  );
  RETURN NEW;
END;
$$;

CREATE FUNCTION app.reject_hard_delete() RETURNS trigger
LANGUAGE plpgsql
AS $$ BEGIN RAISE EXCEPTION 'Hard deletes are prohibited; set deleted_at instead' USING ERRCODE = 'integrity_constraint_violation'; END $$;

CREATE FUNCTION app.reject_audit_mutation() RETURNS trigger
LANGUAGE plpgsql
AS $$ BEGIN RAISE EXCEPTION 'Audit records are immutable' USING ERRCODE = 'integrity_constraint_violation'; END $$;

CREATE TABLE tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$'),
  display_name text NOT NULL,
  branding jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz
);

CREATE TABLE companies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  legal_name text NOT NULL,
  tax_identifier text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id)
);

CREATE TABLE users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  company_id uuid,
  email text NOT NULL,
  display_name text NOT NULL,
  password_hash text,
  mfa_secret text,
  status text NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'active', 'locked', 'disabled')),
  failed_login_count integer NOT NULL DEFAULT 0 CHECK (failed_login_count >= 0),
  locked_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, company_id) REFERENCES companies(tenant_id, id),
  UNIQUE (tenant_id, email)
);

CREATE TABLE roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  name text NOT NULL,
  is_system boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  UNIQUE (tenant_id, name)
);

CREATE TABLE permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  description text NOT NULL
);

CREATE TABLE role_permissions (
  tenant_id uuid NOT NULL,
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL REFERENCES permissions(id),
  PRIMARY KEY (tenant_id, role_id, permission_id),
  FOREIGN KEY (tenant_id, role_id) REFERENCES roles(tenant_id, id)
);

CREATE TABLE user_roles (
  tenant_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, user_id, role_id),
  FOREIGN KEY (tenant_id, user_id) REFERENCES users(tenant_id, id),
  FOREIGN KEY (tenant_id, role_id) REFERENCES roles(tenant_id, id)
);

CREATE TABLE auth_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  user_id uuid NOT NULL,
  refresh_token_hash text NOT NULL,
  device_info text NOT NULL,
  ip_address inet,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, user_id) REFERENCES users(tenant_id, id)
);

CREATE TABLE projects (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  company_id uuid,
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, company_id) REFERENCES companies(tenant_id, id),
  FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id)
);

CREATE TABLE boards (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  project_id uuid NOT NULL,
  name text NOT NULL,
  configuration jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, project_id) REFERENCES projects(tenant_id, id)
);

CREATE TABLE workflow_definitions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  name text NOT NULL,
  definition jsonb NOT NULL,
  version integer NOT NULL CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  UNIQUE (tenant_id, name, version)
);

CREATE TABLE tasks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  board_id uuid NOT NULL,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'review', 'in_progress', 'approved', 'rejected', 'done')),
  assignee_id uuid,
  due_at timestamptz,
  position numeric(20, 8) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, board_id) REFERENCES boards(tenant_id, id),
  FOREIGN KEY (tenant_id, assignee_id) REFERENCES users(tenant_id, id)
);

CREATE TABLE workflow_instances (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  definition_id uuid NOT NULL,
  task_id uuid NOT NULL,
  current_state text NOT NULL,
  state_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  completed_at timestamptz,
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, definition_id) REFERENCES workflow_definitions(tenant_id, id),
  FOREIGN KEY (tenant_id, task_id) REFERENCES tasks(tenant_id, id)
);

CREATE TABLE invoices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  company_id uuid NOT NULL,
  invoice_number text NOT NULL,
  amount numeric(19, 4) NOT NULL CHECK (amount >= 0),
  currency char(3) NOT NULL,
  status text NOT NULL CHECK (status IN ('draft', 'open', 'paid', 'overdue', 'void')),
  due_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, company_id) REFERENCES companies(tenant_id, id),
  UNIQUE (tenant_id, invoice_number)
);

CREATE TABLE expenses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  company_id uuid NOT NULL,
  cost_center text NOT NULL,
  amount numeric(19, 4) NOT NULL CHECK (amount >= 0),
  currency char(3) NOT NULL,
  occurred_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, company_id) REFERENCES companies(tenant_id, id)
);

CREATE TABLE budgets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  company_id uuid NOT NULL,
  cost_center text NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  amount numeric(19, 4) NOT NULL CHECK (amount >= 0),
  currency char(3) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, company_id) REFERENCES companies(tenant_id, id),
  CHECK (period_end >= period_start)
);

CREATE TABLE notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  recipient_id uuid NOT NULL,
  channel text NOT NULL CHECK (channel IN ('email', 'sms', 'push', 'teams', 'websocket')),
  event_type text NOT NULL,
  payload jsonb NOT NULL,
  delivered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, recipient_id) REFERENCES users(tenant_id, id)
);

CREATE TABLE files (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  owner_id uuid NOT NULL,
  object_key text NOT NULL,
  content_type text NOT NULL,
  byte_size bigint NOT NULL CHECK (byte_size >= 0),
  checksum_sha256 char(64) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, owner_id) REFERENCES users(tenant_id, id),
  UNIQUE (tenant_id, object_key)
);

CREATE TABLE embeddings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  file_id uuid NOT NULL,
  external_vector_id text NOT NULL,
  chunk_index integer NOT NULL CHECK (chunk_index >= 0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, file_id) REFERENCES files(tenant_id, id),
  UNIQUE (tenant_id, external_vector_id),
  UNIQUE (tenant_id, file_id, chunk_index)
);

CREATE TABLE ai_conversations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  owner_id uuid NOT NULL,
  title text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, owner_id) REFERENCES users(tenant_id, id)
);

CREATE TABLE ai_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  conversation_id uuid NOT NULL,
  provider text NOT NULL,
  model text NOT NULL,
  status text NOT NULL CHECK (status IN ('running', 'completed', 'failed', 'cancelled')),
  started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  completed_at timestamptz,
  deleted_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  FOREIGN KEY (tenant_id, conversation_id) REFERENCES ai_conversations(tenant_id, id)
);

CREATE TABLE audit_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  actor_id uuid,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  previous_value jsonb,
  new_value jsonb,
  ip_address inet,
  device_info text,
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX tasks_board_status_idx ON tasks (tenant_id, board_id, status) WHERE deleted_at IS NULL;
CREATE INDEX invoices_due_idx ON invoices (tenant_id, due_at) WHERE status IN ('open', 'overdue') AND deleted_at IS NULL;
CREATE INDEX audit_logs_tenant_time_idx ON audit_logs (tenant_id, occurred_at DESC);
CREATE INDEX notifications_recipient_idx ON notifications (tenant_id, recipient_id, created_at DESC);
CREATE INDEX auth_sessions_active_idx ON auth_sessions (tenant_id, user_id, expires_at) WHERE revoked_at IS NULL;

DO $$
DECLARE
  table_name text;
  tenant_tables text[] := ARRAY[
  'companies', 'users', 'roles', 'role_permissions', 'user_roles', 'auth_sessions',
  'projects', 'boards', 'workflow_definitions', 'tasks', 'workflow_instances',
  'invoices', 'expenses', 'budgets', 'notifications', 'files', 'embeddings',
  'ai_conversations', 'ai_sessions', 'audit_logs'
];
  audited_tables text[] := ARRAY[
  'companies', 'users', 'roles', 'role_permissions', 'user_roles', 'auth_sessions',
  'projects', 'boards', 'workflow_definitions', 'tasks', 'workflow_instances',
  'invoices', 'expenses', 'budgets', 'notifications', 'files', 'embeddings',
  'ai_conversations', 'ai_sessions'
];
BEGIN
  FOREACH table_name IN ARRAY tenant_tables LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', table_name);
    EXECUTE format(
      'CREATE POLICY tenant_isolation ON %I USING (tenant_id = app.current_tenant_id()) WITH CHECK (tenant_id = app.current_tenant_id())',
      table_name
    );
    EXECUTE format('CREATE TRIGGER deny_hard_delete BEFORE DELETE ON %I FOR EACH ROW EXECUTE FUNCTION app.reject_hard_delete()', table_name);
  END LOOP;

  ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
  ALTER TABLE tenants FORCE ROW LEVEL SECURITY;
  CREATE POLICY tenant_isolation ON tenants
    USING (id = app.current_tenant_id()) WITH CHECK (id = app.current_tenant_id());
  CREATE TRIGGER deny_tenant_hard_delete BEFORE DELETE ON tenants
    FOR EACH ROW EXECUTE FUNCTION app.reject_hard_delete();

  FOREACH table_name IN ARRAY audited_tables LOOP
    EXECUTE format('CREATE TRIGGER write_audit AFTER INSERT OR UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION app.write_audit_log()', table_name);
  END LOOP;
END;
$$;

CREATE TRIGGER immutable_audit_logs BEFORE UPDATE OR DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION app.reject_audit_mutation();

COMMIT;