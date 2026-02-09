#!/bin/bash
set -e
echo "=== Deploying Distributed Tracing Example ==="

echo -e "\n1. Installing Jaeger (if not present)..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml 2>/dev/null || echo "Jaeger may already be installed"

echo -e "\n2. Creating namespace and apps..."
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --all -n tracing-demo --timeout=120s

echo -e "\n=== Deployment Complete ==="
echo "Access Jaeger UI:"
echo "  kubectl port-forward svc/tracing 16686:80 -n istio-system"
echo "  Open http://localhost:16686"
