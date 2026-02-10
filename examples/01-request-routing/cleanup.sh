#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all request routing demo resources
# ============================================================================
# Deletes the "routing-demo" namespace, removing all 3 version deployments,
# the service, Gateway, VirtualService, and DestinationRule.
# ============================================================================

echo "=== Cleaning Up Request Routing Example ==="
kubectl delete namespace routing-demo --ignore-not-found
echo "=== Cleanup Complete ==="
