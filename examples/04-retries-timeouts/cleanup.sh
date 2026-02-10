#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all retries/timeouts demo resources
# ============================================================================
# Deletes the "retry-demo" namespace, removing httpbin, Gateway,
# VirtualService, and all associated resources.
# ============================================================================

echo "=== Cleaning Up ==="
kubectl delete namespace retry-demo --ignore-not-found
echo "=== Done ==="
