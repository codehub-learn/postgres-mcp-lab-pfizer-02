#!/usr/bin/env bash
# Reset the lab to the clean baseline: delete the database volume, remove learner-made artifacts,
# rebuild, and wait until the database is healthy.
# Usage: scripts/reset-lab.sh [--keep-learner-files]
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || { echo "missing .env (copy .env.example to .env)" >&2; exit 1; }
set -a; source .env; set +a

keep=false; [ "${1:-}" = "--keep-learner-files" ] && keep=true

echo "== dataset"
bash scripts/fetch-dataset.sh >/dev/null && echo "dataset ok"

echo "== stop and delete the database volume"
docker compose --profile mcp down -v

if [ "$keep" = false ]; then
  echo "== remove files created by learners and agents"
  find db/migrations -type f ! -name '.gitkeep' -delete
  rm -f docs/schema-guide.md logs/queries.log
fi

echo "== start everything"
docker compose --profile mcp up -d --build

echo "== wait for the database"
for _ in $(seq 1 300); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' pgmcplab-db 2>/dev/null || true)" = healthy ] && break
  sleep 3
done
[ "$(docker inspect -f '{{.State.Health.Status}}' pgmcplab-db)" = healthy ] || { echo "database did not become healthy" >&2; exit 1; }
echo "lab reset: database healthy. Run scripts/verify-lab.sh to check."
