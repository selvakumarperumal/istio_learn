#!/bin/bash
# cleanup.sh - Remove all resources

echo "=== Cleaning Up Traffic Splitting Example ==="

kubectl delete namespace traffic-demo --ignore-not-found

echo "=== Cleanup Complete ==="
kubectl get namespace traffic-demo 2>/dev/null || echo "Namespace deleted successfully"
