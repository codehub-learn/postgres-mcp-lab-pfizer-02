# Reference Postgres MCP server (archived, stdio only) exposed over Streamable HTTP by supergateway.
FROM node:24-alpine
ARG SUPERGATEWAY_VERSION=4.1.0
ARG PG_MCP_VERSION=0.6.2
RUN npm install -g --no-fund --no-audit supergateway@${SUPERGATEWAY_VERSION} @modelcontextprotocol/server-postgres@${PG_MCP_VERSION}
USER node
EXPOSE 8000
# Endpoint: http://<host>:8000/mcp
CMD ["sh", "-c", "exec supergateway --stdio \"mcp-server-postgres postgresql://mcp_readonly:${MCP_READONLY_PASSWORD}@db:5432/${POSTGRES_DB}\" --outputTransport streamableHttp --port 8000"]
