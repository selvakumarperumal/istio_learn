#!/bin/bash
set -e
echo "=== Deploying Authorization Policy Example ==="
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --all -n authz-demo --timeout=120s
echo -e "\n=== Deployment Complete ==="
echo "Run: kubectl apply -f authz-deny-all.yaml    # Deny all"
echo "Run: kubectl apply -f authz-allow-specific.yaml  # Allow sleep"
