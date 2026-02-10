#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the Authorization Policy demo
# ============================================================================
# Deploys httpbin (server) and sleep (client) with ServiceAccounts.
# ServiceAccounts provide the IDENTITY that AuthorizationPolicy checks.
#
# AFTER DEPLOYMENT:
#   1. Apply deny-all to block everything:
#      kubectl apply -f authz-deny-all.yaml
#   2. Apply allow-specific to grant sleep access:
#      kubectl apply -f authz-allow-specific.yaml
#   3. Run ./test.sh to verify the policies
# ============================================================================

set -e
echo "=== Deploying Authorization Policy Example ==="

# Step 1: Create namespace with Istio sidecar injection
kubectl apply -f namespace.yaml

# Step 2: Deploy httpbin + sleep with ServiceAccounts
kubectl apply -f deployment.yaml

# Step 3: Wait for all pods to be Ready
kubectl wait --for=condition=Ready pods --all -n authz-demo --timeout=120s

echo -e "\n=== Deployment Complete ==="
echo "Run: kubectl apply -f authz-deny-all.yaml    # Deny all"
echo "Run: kubectl apply -f authz-allow-specific.yaml  # Allow sleep"
