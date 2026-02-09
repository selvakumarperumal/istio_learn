#!/bin/bash
set -e

echo "=== Deploying Circuit Breaker Example ==="

echo -e "\n1. Creating namespace..."
kubectl apply -f namespace.yaml

echo -e "\n2. Deploying httpbin..."
kubectl apply -f deployment.yaml

echo -e "\n3. Deploying fortio client..."
kubectl apply -f fortio-client.yaml

echo -e "\n4. Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n circuit-demo --timeout=120s

echo -e "\n5. Applying circuit breaker..."
kubectl apply -f destination-rule.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n circuit-demo
echo -e "\nRun ./test.sh to test circuit breaker"
