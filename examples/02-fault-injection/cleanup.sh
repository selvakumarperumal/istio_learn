#!/bin/bash
# cleanup.sh - Remove all resources

echo "=== Cleaning Up Fault Injection Example ==="
kubectl delete namespace fault-demo --ignore-not-found
echo "=== Cleanup Complete ==="
