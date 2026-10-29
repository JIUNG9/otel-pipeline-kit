#!/usr/bin/env bash
# Fail if any pipeline in configs/ lists a processor other than memory_limiter
# first. Matches the one-line `processors: [a, b]` form these configs use.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
status=0

for cfg in "$ROOT"/configs/*.yaml; do
  name="$(basename "$cfg")"
  lines="$(grep -E '^[[:space:]]+processors:' "$cfg" || true)"
  if [ -z "$lines" ]; then
    echo "FAIL  $name: no pipeline processors found"
    status=1
    continue
  fi
  while IFS= read -r line; do
    if ! grep -Eq 'processors:[[:space:]]*\[memory_limiter([],])' <<<"$line"; then
      echo "FAIL  $name: memory_limiter is not first:$line"
      status=1
    fi
  done <<<"$lines"
  [ "$status" -eq 0 ] && echo "ok    $name"
done
exit "$status"
