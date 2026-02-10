#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all traffic splitting demo resources
# ============================================================================
# Deletes the "traffic-demo" namespace, removing:
#   - reviews-v1 (3 replicas) and reviews-v2 (1 replica) Deployments
#   - reviews-svc Service
#   - DestinationRule, VirtualService, and Gateway
# ============================================================================

echo "=== Cleaning Up Traffic Splitting Example ==="

kubectl delete namespace traffic-demo --ignore-not-found

echo "=== Cleanup Complete ==="
kubectl get namespace traffic-demo 2>/dev/null || echo "Namespace deleted successfully"
