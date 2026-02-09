#!/bin/bash
set -e
echo "=== Deploying Egress Traffic Example ==="
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --all -n egress-demo --timeout=120s
kubectl apply -f serviceentry.yaml
echo -e "\n=== Deployment Complete ==="
kubectl get pods -n egress-demo
