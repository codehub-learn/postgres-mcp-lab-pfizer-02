#!/usr/bin/env node
// PreToolUse hook: guard and log SQL sent to the Postgres MCP servers.
// Works with the hook payloads of both Claude Code (tool_name/tool_input) and
// GitHub Copilot CLI (toolName/toolArgs). Reads JSON on stdin, writes a decision on stdout.
//
// Policy
//   - Always blocked on every server: DROP, TRUNCATE, UPDATE/DELETE without WHERE.
//   - Blocked on the read-only servers (anything that is not "unrestricted"): every statement that
//     changes data or schema. The database role already refuses these; the hook makes the reason
//     visible to the agent and keeps a log.
//   - Every SQL call is appended to logs/queries.log (JSON lines).
import { appendFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const logFile = join(root, 'logs', 'queries.log');

let raw = '';
for await (const chunk of process.stdin) raw += chunk;
let input = {};
try { input = JSON.parse(raw || '{}'); } catch { /* fall through: allow */ }

const copilot = 'toolName' in input;
const toolName = String(input.tool_name ?? input.toolName ?? '');
let args = input.tool_input ?? input.toolArgs ?? {};
if (typeof args === 'string') { try { args = JSON.parse(args); } catch { args = {}; } }

// Find the SQL text: both free-SQL servers (reference `query`, crystaldba `execute_sql`) take an argument named `sql`.
// Other tools (shell, edit, toolbox fixed tools) have no `sql` argument and are not guarded here.
const sql = typeof args === 'object' && args !== null ? String(args.sql ?? '') : '';
if (!sql) process.exit(0);

// Strip comments and string literals so keywords inside them do not trigger the rules.
const clean = sql
  .replace(/\/\*[\s\S]*?\*\//g, ' ')
  .replace(/--[^\n]*/g, ' ')
  .replace(/'(?:[^']|'')*'/g, "''")
  .replace(/\$([A-Za-z_]*)\$[\s\S]*?\$\1\$/g, "''")
  .toLowerCase();
const statements = clean.split(';').map((s) => s.trim()).filter(Boolean);

const unrestricted = /unrestricted/i.test(toolName);
const mutating = /^(insert|update|delete|drop|truncate|alter|create|grant|revoke|copy|vacuum|reindex|cluster|call|do|merge|comment|lock|refresh|reset|set|begin|commit|rollback|prepare|execute)\b/;

let reason = '';
for (const s of statements) {
  if (/^(drop|truncate)\b/.test(s)) { reason = 'DROP and TRUNCATE are never allowed from the agent.'; break; }
  if (/^(update|delete)\b/.test(s) && !/\bwhere\b/.test(s)) { reason = 'UPDATE/DELETE without a WHERE clause is not allowed.'; break; }
  if (!unrestricted && mutating.test(s)) {
    reason = 'This MCP server is read-only; this statement changes state or session settings. Use only SELECT or EXPLAIN here. For schema changes use the DBA workflow with the unrestricted server.';
    break;
  }
}
if (!reason && statements.length > 1 && !unrestricted) {
  reason = 'Send one statement per call on the read-only servers.';
}

const decision = reason ? 'deny' : 'allow';
try {
  mkdirSync(dirname(logFile), { recursive: true });
  appendFileSync(logFile, JSON.stringify({ ts: new Date().toISOString(), tool: toolName, decision, sql: sql.slice(0, 2000) }) + '\n');
} catch { /* logging must never break the hook */ }

if (decision === 'deny') {
  const out = copilot
    ? { permissionDecision: 'deny', permissionDecisionReason: reason }
    : { hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: reason } };
  process.stdout.write(JSON.stringify(out));
}
process.exit(0);
