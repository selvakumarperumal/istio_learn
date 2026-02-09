#!/bin/bash
kubectl delete namespace lb-demo --ignore-not-found
echo "=== Cleanup Complete ==="
