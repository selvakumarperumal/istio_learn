#!/bin/bash
set -e
echo "=== Deploying JWT Auth Example ==="
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f gateway.yaml
kubectl wait --for=condition=Ready pods --all -n jwt-demo --timeout=120s

echo -e "\nApplying JWT authentication..."
kubectl apply -f requestauthentication.yaml
kubectl apply -f authorizationpolicy.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n jwt-demo
echo -e "\nRun ./test.sh to test JWT authentication"
