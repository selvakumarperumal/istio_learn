#!/bin/bash
echo "=== Cleaning Up ==="
kubectl delete namespace retry-demo --ignore-not-found
echo "=== Done ==="
