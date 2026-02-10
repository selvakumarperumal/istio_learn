#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all circuit breaker demo resources
# ============================================================================
# Deletes the entire "circuit-demo" namespace, removing:
#   - httpbin Deployment, Service, and pods
#   - fortio Deployment, Service, and pods
#   - DestinationRule (circuit breaker configuration)
#   - Any other resources in the namespace
#
# The Istio control plane and ingress gateway are NOT affected.
# ============================================================================

echo "=== Cleaning Up Circuit Breaker Example ==="
kubectl delete namespace circuit-demo --ignore-not-found
echo "=== Cleanup Complete ==="
