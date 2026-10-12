-- mcp_admin owns the schema and tables (needed for CREATE INDEX / ALTER TABLE).
-- mcp_readonly can only SELECT, and its sessions default to read-only transactions.
ALTER SCHEMA olist OWNER TO mcp_admin;
DO $$
DECLARE t record;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'olist' LOOP
    EXECUTE format('ALTER TABLE olist.%I OWNER TO mcp_admin', t.tablename);
  END LOOP;
END $$;

GRANT USAGE ON SCHEMA olist TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA olist TO mcp_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE mcp_admin IN SCHEMA olist GRANT SELECT ON TABLES TO mcp_readonly;

-- Stats views (pg_stat_statements, EXPLAIN tooling) without superuser.
GRANT pg_monitor TO mcp_readonly;
GRANT pg_monitor TO mcp_admin;

ALTER ROLE mcp_readonly SET search_path = olist, public;
ALTER ROLE mcp_readonly SET default_transaction_read_only = on;
ALTER ROLE mcp_readonly SET statement_timeout = '30s';
ALTER ROLE mcp_admin    SET search_path = olist, public;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- hypopg what-if indexing (used by crystaldba analyze_query_indexes) reads these views.
GRANT SELECT ON public.hypopg_list_indexes, public.hypopg_hidden_indexes TO mcp_readonly, mcp_admin;

-- The migration runner (scripts/apply-sql) records applied versions in public.schema_migrations.
GRANT CREATE ON SCHEMA public TO mcp_admin;
