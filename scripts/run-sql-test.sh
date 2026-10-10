#!/usr/bin/env bash
# Executa um teste SQL no banco local em transação revertida; falha se algum caso não passar ou houver erro.
H=${PGTEST_HOST:-/home/claude/.pgtest}; P=${PGTEST_PORT:-54329}; DB=${PGTEST_DB:-auditapro_test}
out=$( { echo "begin;"; cat "$1"; echo "rollback;"; } | psql -h "$H" -p "$P" -U postgres -d "$DB" -v ON_ERROR_STOP=1 -q -A -F ' | ' -P footer=off 2>&1 )
status=$?
echo "$out" | grep -E '^ERROR|^[0-9]+ \| .* \| [tf] \|' | cut -c1-${WIDTH:-170}
fails=$(echo "$out" | grep -cE '^[0-9]+ \| .* \| f \|')
total=$(echo "$out" | grep -cE '^[0-9]+ \| .* \| [tf] \|')
echo "---- $((total-fails))/$total casos aprovados (psql=$status)"
[ "$status" -eq 0 ] && [ "$fails" -eq 0 ] && [ "$total" -gt 0 ]
