#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the Retries and Timeouts demo
# ============================================================================
# Deploys: namespace → httpbin (Deployment+Service) → Gateway → VirtualService
#
# The VirtualService configures: 3 retries, 2s perTryTimeout, 10s total timeout
#
# AFTER DEPLOYMENT:
#   ./test.sh                    # Run automated tests
#   curl $GATEWAY_URL/status/503 # Test retries (503 triggers retry)
#   curl $GATEWAY_URL/delay/15   # Test timeout (15s > 10s timeout)
# ============================================================================

set -e
echo "=== Deploying Retries/Timeouts Example ==="

# Step 1: Create namespace with Istio sidecar injection
kubectl apply -f namespace.yaml

# Step 2: Deploy httpbin service
kubectl apply -f deployment.yaml

# Step 3: Wait for pods to be Ready (app container + Envoy sidecar)
kubectl wait --for=condition=Ready pods --all -n retry-demo --timeout=120s

# Step 4: Apply Gateway for external access
kubectl apply -f gateway.yaml

# Step 5: Apply VirtualService with retry and timeout policies
kubectl apply -f virtual-service.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n retry-demo
