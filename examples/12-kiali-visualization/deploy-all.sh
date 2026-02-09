#!/bin/bash
set -e
echo "=== Deploying Kiali ==="

echo -e "\n1. Installing Kiali..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

echo -e "\n2. Waiting for Kiali..."
kubectl wait --for=condition=Ready pods -l app=kiali -n istio-system --timeout=120s

echo -e "\n=== Deployment Complete ==="
echo "Access Kiali:"
echo "  kubectl port-forward svc/kiali 20001:20001 -n istio-system"
echo "  Open http://localhost:20001"
