#!/bin/bash
set -e
echo "=== Deploying mTLS Example ==="
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --all -n mtls-demo --timeout=120s
echo -e "\nApplying STRICT mTLS..."
kubectl apply -f peerauthentication-strict.yaml
echo -e "\n=== Deployment Complete ==="
kubectl get pods -n mtls-demo
echo -e "\nTo switch to permissive: kubectl apply -f peerauthentication-permissive.yaml"
