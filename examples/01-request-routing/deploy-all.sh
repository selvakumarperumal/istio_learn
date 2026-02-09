#!/bin/bash
# deploy-all.sh - Deploy request routing example

set -e

echo "=== Deploying Request Routing Example ==="

echo -e "\n1. Creating namespace..."
kubectl apply -f namespace.yaml

echo -e "\n2. Deploying v1, v2, v3..."
kubectl apply -f deployment.yaml

echo -e "\n3. Creating service..."
kubectl apply -f service.yaml

echo -e "\n4. Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n routing-demo --timeout=120s

echo -e "\n5. Applying Istio resources..."
kubectl apply -f destination-rule.yaml
kubectl apply -f virtual-service.yaml
kubectl apply -f gateway.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n routing-demo
echo -e "\nRun ./test.sh to verify routing"
