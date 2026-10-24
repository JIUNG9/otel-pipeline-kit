# otel-pipeline-kit

Reference configs and tests for an OpenTelemetry Collector pipeline that does not silently lose telemetry when a collector restarts or runs out of memory. For platform and SRE teams running a gateway and agent collector tier on Kubernetes.

## Why

The Collector's exporter queue (`sending_queue`) is held in memory by default. When a collector pod is OOM-killed, evicted or rolled, everything queued in it is gone, and nothing reports the loss. A collector with no `memory_limiter` is the usual cause of the OOM in the first place: a traffic burst or a slow backend grows the queue until the kernel kills the process.

This kit pairs the two fixes and tests them together:

- `memory_limiter` first in every pipeline, so an overloaded collector refuses new data (senders retry) instead of dying.
- A `file_storage` extension behind each exporter queue, so queued data survives a restart.
- A load test that restarts collectors mid-stream and checks how much was lost.

## Quick start

Nothing runnable yet. The configs, Helm values and tests are tracked in the roadmap below; this README is updated with the commands as each piece lands.

## How it works

Planned layout, one collector tier per role:

| Tier | Role | Protection |
| --- | --- | --- |
| agent | receives OTLP from workloads on the node | `memory_limiter`, persistent queue |
| gateway | batches and exports to the backend | `memory_limiter`, persistent queue, bearer-auth OTLP receiver |

A persistent queue needs a volume that outlives the pod (a PersistentVolumeClaim, or a node-local path for the agent tier). Without one, `file_storage` only survives a container restart, not a pod reschedule. The quick start will say which case it covers.

## Status

Early. The repo has CI and the OSS hygiene check; the configs are not written yet. Planned, in order:

1. Gateway and agent collector configs with `file_storage` queues and `memory_limiter`
2. Helm values and a kind-based quick start
3. `telemetrygen` load test with a restart script that asserts zero drops
4. OTLP bearer-auth receiver example, and a note on never exposing OTLP publicly
5. Prometheus alert rules and a dashboard for queue depth, drops and refused spans
6. CI: `otelcol validate` on every config, kind smoke test

## License

MIT
