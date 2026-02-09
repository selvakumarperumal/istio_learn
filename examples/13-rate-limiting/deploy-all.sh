#!/bin/bash
set -e
echo "=== Deploying Rate Limiting Example ==="
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --all -n ratelimit-demo --timeout=120s
kubectl apply -f envoyfilter.yaml
echo -e "\n=== Deployment Complete ==="
echo "Rate limit: 10 requests per minute"
kubectl get pods -n ratelimit-demo
