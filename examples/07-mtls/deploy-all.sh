#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the mutual TLS (mTLS) demo
# ============================================================================
# Deploys httpbin (server) and sleep (client), then applies STRICT mTLS.
# With STRICT mode, only pods with Istio sidecars can communicate.
#
# TO TEST:
#   1. From sleep (has sidecar → works):
#      kubectl exec -n mtls-demo deploy/sleep -- curl http://httpbin:80/get
#
#   2. From a non-mesh pod (no sidecar → BLOCKED in STRICT mode)
#
# TO SWITCH MODES:
#   kubectl apply -f peerauthentication-permissive.yaml  # Allow both
#   kubectl apply -f peerauthentication-strict.yaml      # Require mTLS
# ============================================================================

set -e
echo "=== Deploying mTLS Example ==="

# Step 1: Create namespace with Istio sidecar injection
kubectl apply -f namespace.yaml

# Step 2: Deploy httpbin (server) and sleep (client)
kubectl apply -f deployment.yaml

# Step 3: Wait for all pods (both containers + sidecars)
kubectl wait --for=condition=Ready pods --all -n mtls-demo --timeout=120s

# Step 4: Apply STRICT mTLS as the default mode
echo -e "\nApplying STRICT mTLS..."
kubectl apply -f peerauthentication-strict.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n mtls-demo
echo -e "\nTo switch to permissive: kubectl apply -f peerauthentication-permissive.yaml"
