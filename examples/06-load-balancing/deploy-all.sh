#!/bin/bash
set -e
echo "=== Deploying Load Balancing Example ==="
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --all -n lb-demo --timeout=120s
echo -e "\nApplying Round Robin (default)..."
kubectl apply -f lb-round-robin.yaml
echo -e "\n=== Deployment Complete ==="
kubectl get pods -n lb-demo
echo -e "\nTo test different algorithms:"
echo "  kubectl apply -f lb-random.yaml"
echo "  kubectl apply -f lb-least-conn.yaml"
echo "  kubectl apply -f lb-consistent-hash.yaml"
