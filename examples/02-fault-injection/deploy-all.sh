#!/bin/bash
# deploy-all.sh - Deploy fault injection example

set -e

echo "=== Deploying Fault Injection Example ==="

echo -e "\n1. Creating namespace..."
kubectl apply -f namespace.yaml

echo -e "\n2. Deploying httpbin..."
kubectl apply -f deployment.yaml

echo -e "\n3. Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n fault-demo --timeout=120s

echo -e "\n4. Applying gateway..."
kubectl apply -f gateway.yaml

echo -e "\n5. Choose fault type to inject:"
echo "   a) kubectl apply -f fault-delay.yaml    # Delay injection"
echo "   b) kubectl apply -f fault-abort.yaml    # Abort injection"
echo "   c) kubectl apply -f fault-combined.yaml # Both"

echo -e "\nApplying delay injection by default..."
kubectl apply -f fault-delay.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n fault-demo
echo -e "\nRun ./test.sh to test fault injection"
