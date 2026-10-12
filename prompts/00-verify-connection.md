# 00 Verify the MCP connection

Paste one block into the agent. Replace `<server>` with the MCP server name from `.mcp.json`
(`pg-reference`, `pg-crystaldba-restricted`, `pg-crystaldba-unrestricted`, `pg-toolbox`).
The agent must use only that server. Do not let it work around a failure.

## Free-form SQL servers (pg-reference, pg-crystaldba-restricted, pg-crystaldba-unrestricted)

```text
Use only the MCP server "<server>". Do not use shell commands or any other tool.
1. List the tools this server offers, in one line.
2. Run: SELECT count(*) FROM olist.orders;  and report the number.
3. Run exactly: UPDATE olist.orders SET order_status = 'x' WHERE false;
   Report whether it succeeded or failed and quote the error. Do not try any workaround.
4. Tell me which database role you appear to be connected as (run SELECT current_user;).
```

Expected:

| Server | Tools | count | UPDATE | current_user |
|---|---|---|---|---|
| pg-reference | `query` | 99441 | fails (read-only transaction) | `mcp_readonly` |
| pg-crystaldba-restricted | 9 tools | 99441 | fails (query validation) | `mcp_readonly` |
| pg-crystaldba-unrestricted | 9 tools | 99441 | succeeds, 0 rows | `mcp_admin` |

## Curated-tool server (pg-toolbox)

```text
Use only the MCP server "pg-toolbox". Do not use shell commands or any other tool.
1. List the tools this server offers, in one line.
2. Call list_tables and tell me how many tables are in the olist schema.
3. Call late_delivery_rate_by_state and give me the three states with the highest late percentage.
4. Can you run an UPDATE statement with this server? Answer from the tools you have, do not guess.
```

Expected: 4 tools; 9 tables in `olist`; top late states are AL, MA, PI (23.9, 19.7, 16.0 percent); no, there is no tool that accepts free SQL.
