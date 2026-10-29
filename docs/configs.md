# Collector configs

`configs/gateway.yaml` and `configs/agent.yaml` are the two tiers. Both put
`memory_limiter` first in every pipeline and back the exporter queue with a
`file_storage` extension.

## Environment variables

| Variable | Used by | Meaning |
| --- | --- | --- |
| `BACKEND_OTLP_ENDPOINT` | gateway | OTLP/HTTP endpoint of the backend, for example `https://otlp.backend.example.com` |
| `GATEWAY_OTLP_ENDPOINT` | agent | `host:port` of the gateway OTLP gRPC receiver |
| `GATEWAY_OTLP_INSECURE` | agent | `true` for plaintext to the gateway, `false` to verify TLS |

## Memory sizing

`memory_limiter` compares the collector's Go heap against `limit_mib`. Above
`limit_mib - spike_limit_mib` (the soft limit) it refuses new data and forces a GC;
senders see an error and retry. The limit must sit below the container memory limit,
because the process also uses memory the limiter does not count (stacks, the file
mappings used by the queue).

| Tier | Container limit | `limit_mib` | `spike_limit_mib` | Soft limit |
| --- | --- | --- | --- | --- |
| gateway | 2Gi (2048 MiB) | 1600 | 400 | 1200 MiB |
| agent | 512Mi | 400 | 100 | 300 MiB |

Both keep `limit_mib` at about 80% of the container limit and the spike at 25% of
`limit_mib`. These are starting values. Change them with the container limit, and
watch `otelcol_processor_refused_spans` to see whether the limiter is firing.

## Persistent queue

`sending_queue.storage` points the exporter at the `file_storage/queue` extension, so
queued batches are written to disk and reloaded on start. Things that decide whether
data survives:

- `/var/lib/otelcol/queue` must be a volume that outlives the container. With no
  volume mounted the directory does not exist and the collector fails at start. That
  is intended: `create_directory` is left off so a missing volume is an error and not
  a silent fall-back to the container filesystem.
- The gateway needs a PersistentVolumeClaim. The agent needs a `hostPath` volume, or
  its queue is lost when the pod is rescheduled to another node.
- `compaction.directory` is `/tmp`, which the collector image does not ship. Mount an
  `emptyDir` there.
- `queue_size` counts batches, not spans. At the gateway's `send_batch_max_size` of
  8192 items, 5000 batches is the upper bound on items held; size the volume from
  your average item size.
- `retry_on_failure.max_elapsed_time` is 600s. A backend outage longer than that drops
  the batch being retried. Raise it if your outages run longer and the volume can hold
  the backlog.

## Validate

```bash
make test
```

`check-order` fails if a pipeline lists any processor before `memory_limiter`.
`validate` runs `otelcol validate` from the contrib image (pinned in
`scripts/validate-configs.sh`) on every file in `configs/`, and needs Docker.
