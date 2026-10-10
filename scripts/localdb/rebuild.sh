#!/usr/bin/env bash
# Recria o banco local de testes: stubs Supabase + todas as migrations versionadas, em ordem.
set -euo pipefail
H=${PGTEST_HOST:-/home/claude/.pgtest}; P=${PGTEST_PORT:-54329}; DB=${PGTEST_DB:-auditapro_test}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
psql -h "$H" -p "$P" -U postgres -qAtc "drop database if exists $DB" -c "create database $DB" >/dev/null
psql -h "$H" -p "$P" -U postgres -d "$DB" -q -v ON_ERROR_STOP=1 -f "$ROOT/scripts/localdb/00-supabase-stubs.sql" >/dev/null
for f in "$ROOT"/outputs/audita-pro-supabase/supabase/migrations/*.sql; do
  if ! out=$(psql -h "$H" -p "$P" -U postgres -d "$DB" -q -v ON_ERROR_STOP=1 -1 -f "$f" 2>&1); then
    echo "FALHOU: $(basename "$f")"; echo "$out" | grep -v NOTICE | head -8; exit 1; fi
done
echo "ok: $(ls "$ROOT"/outputs/audita-pro-supabase/supabase/migrations/*.sql | wc -l) migrations aplicadas em $DB"
if [ "${1:-}" != "--no-fixtures" ]; then
  psql -h "$H" -p "$P" -U postgres -d "$DB" -q -v ON_ERROR_STOP=1 -f "$ROOT/scripts/localdb/10-fixtures.sql" 2>&1 | grep -v NOTICE || true
  echo "ok: dados de teste carregados"
fi
