#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the Distributed Tracing demo
# ============================================================================
# WHAT GETS DEPLOYED:
#   1. Jaeger tracing backend (in istio-system namespace)
#   2. httpbin + sleep in tracing-demo namespace
#
# AFTER DEPLOYMENT:
#   1. Run ./test.sh to generate traffic and traces
#   2. Access Jaeger UI:
#      kubectl port-forward svc/tracing 16686:80 -n istio-system
#      Open http://localhost:16686
#   3. Select "httpbin.tracing-demo" service and click "Find Traces"
# ============================================================================

set -e
echo "=== Deploying Distributed Tracing Example ==="

# Step 1: Install Jaeger tracing backend (if not already present)
# Jaeger is deployed to istio-system and collects spans from all namespaces
echo -e "\n1. Installing Jaeger (if not present)..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/jaeger.yaml 2>/dev/null || echo "Jaeger may already be installed"

# Step 2: Create namespace and deploy demo applications
echo -e "\n2. Creating namespace and apps..."
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --all -n tracing-demo --timeout=120s

echo -e "\n=== Deployment Complete ==="
echo "Access Jaeger UI:"
echo "  kubectl port-forward svc/tracing 16686:80 -n istio-system"
echo "  Open http://localhost:16686"
