#!/bin/bash
echo "=== Cleaning Up Circuit Breaker Example ==="
kubectl delete namespace circuit-demo --ignore-not-found
echo "=== Cleanup Complete ==="
