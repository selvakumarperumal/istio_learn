#!/bin/bash
set -e
echo "=== Deploying Retries/Timeouts Example ==="
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --all -n retry-demo --timeout=120s
kubectl apply -f gateway.yaml
kubectl apply -f virtual-service.yaml
echo -e "\n=== Deployment Complete ==="
kubectl get pods -n retry-demo
