#!/bin/bash
# cleanup.sh - Remove all resources

echo "=== Cleaning Up Request Routing Example ==="
kubectl delete namespace routing-demo --ignore-not-found
echo "=== Cleanup Complete ==="
