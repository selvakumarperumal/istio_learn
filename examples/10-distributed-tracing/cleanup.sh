#!/bin/bash
kubectl delete namespace tracing-demo --ignore-not-found
echo "=== Cleanup Complete ==="
echo "Note: Jaeger addon in istio-system is NOT deleted"
