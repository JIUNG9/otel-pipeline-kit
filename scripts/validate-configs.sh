#!/usr/bin/env bash
# Run `otelcol validate` on every config in configs/ using the contrib image.
# The queue and compaction directories must exist at start (the image has no
# /tmp), so both are mounted as tmpfs here.
set -euo pipefail

IMAGE="${OTELCOL_IMAGE:-otel/opentelemetry-collector-contrib:0.116.1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
status=0

for cfg in "$ROOT"/configs/*.yaml; do
  name="$(basename "$cfg")"
  if docker run --rm \
      --tmpfs /var/lib/otelcol/queue \
      --tmpfs /tmp \
      -v "$ROOT/configs:/configs:ro" \
      -e BACKEND_OTLP_ENDPOINT=https://otlp.backend.example.com \
      -e GATEWAY_OTLP_ENDPOINT=gateway.observability.svc:4317 \
      -e GATEWAY_OTLP_INSECURE=true \
      "$IMAGE" validate --config="/configs/$name" >/dev/null 2>/tmp/otelcol-validate.err; then
    echo "ok    $name"
  else
    echo "FAIL  $name"
    cat /tmp/otelcol-validate.err
    status=1
  fi
done
exit "$status"
