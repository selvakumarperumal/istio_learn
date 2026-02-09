#!/bin/bash
set -e
echo "=== Deploying Traffic Mirroring Example ==="
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --all -n mirror-demo --timeout=120s
kubectl apply -f destination-rule.yaml
kubectl apply -f virtual-service.yaml
echo -e "\n=== Deployment Complete ==="
kubectl get pods -n mirror-demo
