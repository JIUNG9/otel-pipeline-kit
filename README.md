# otel-pipeline-kit

Reference configs and tests for an OpenTelemetry Collector pipeline that does not silently lose telemetry when a collector restarts or runs out of memory. For platform and SRE teams running a gateway and agent collector tier on Kubernetes.

## Why

The Collector's exporter queue (`sending_queue`) is held in memory by default. When a collector pod is OOM-killed, evicted or rolled, everything queued in it is gone, and nothing reports the loss. A collector with no `memory_limiter` is the usual cause of the OOM in the first place: a traffic burst or a slow backend grows the queue until the kernel kills the process.

This kit pairs the two fixes and tests them together:

- `memory_limiter` first in every pipeline, so an overloaded collector refuses new data (senders retry) instead of dying.
- A `file_storage` extension behind each exporter queue, so queued data survives a restart.
- A load test that restarts collectors mid-stream and checks how much was lost.

## Quick start

The two collector configs are in `configs/`. Check them with Docker installed:

```bash
make test
```

That fails if a pipeline does not start with `memory_limiter`, then runs `otelcol validate` on each config. Environment variables, memory sizing and volume requirements are in [docs/configs.md](docs/configs.md). Helm values and the load test are not written yet.

## How it works

One collector tier per role. The bearer-auth receiver is planned and not in the configs yet:

| Tier | Role | Protection |
| --- | --- | --- |
| agent | receives OTLP from workloads on the node | `memory_limiter`, persistent queue |
| gateway | batches and exports to the backend | `memory_limiter`, persistent queue, bearer-auth OTLP receiver |

A persistent queue needs a volume that outlives the pod (a PersistentVolumeClaim, or a node-local path for the agent tier). Without one, `file_storage` only survives a container restart, not a pod reschedule. The quick start will say which case it covers.

## Status

Early. The repo has CI, the OSS hygiene check and the gateway and agent configs, validated against the contrib collector 0.116.1. Not yet tested under load or restarts. Planned, in order:

1. Helm values and a kind-based quick start
2. `telemetrygen` load test with a restart script that asserts zero drops
3. OTLP bearer-auth receiver example, and a note on never exposing OTLP publicly
4. Prometheus alert rules and a dashboard for queue depth, drops and refused spans
5. CI: kind smoke test

## License

MIT
