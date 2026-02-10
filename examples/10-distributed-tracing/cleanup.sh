#!/bin/bash
# ============================================================================
# cleanup.sh - Remove distributed tracing demo resources
# ============================================================================
# Deletes the "tracing-demo" namespace (httpbin + sleep).
# NOTE: Jaeger in istio-system is NOT deleted — it may be used by other
# examples and is shared across the mesh.
# ============================================================================

kubectl delete namespace tracing-demo --ignore-not-found
echo "=== Cleanup Complete ==="
echo "Note: Jaeger addon in istio-system is NOT deleted"
