.PHONY: test validate check-order

test: check-order validate

# Every pipeline starts with memory_limiter.
check-order:
	scripts/check-memory-limiter.sh

# otelcol validate on every config (needs Docker).
validate:
	scripts/validate-configs.sh
