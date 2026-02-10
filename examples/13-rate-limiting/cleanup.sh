#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all rate limiting demo resources
# ============================================================================
# Deletes the "ratelimit-demo" namespace, removing httpbin, Service,
# and the EnvoyFilter rate limit configuration.
# ============================================================================

kubectl delete namespace ratelimit-demo --ignore-not-found
echo "=== Cleanup Complete ==="
