#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the Traffic Mirroring (Shadow Traffic) demo
# ============================================================================
# Deploys two versions of httpbin:
#   - v1: Production (receives all real traffic, responses go to clients)
#   - v2: Canary (receives mirrored copies, responses are discarded)
#
# DEPLOYMENT ORDER:
#   1. Namespace → 2. Deployments+Service → 3. DestinationRule → 4. VirtualService
#   DestinationRule defines subsets (v1/v2) that VirtualService references,
#   so it must be applied before the VirtualService.
#
# AFTER DEPLOYMENT:
#   - Send traffic to httpbin via v1 pod or gateway
#   - Check v2 logs to see mirrored requests arriving
#   - Run ./test.sh for automated verification
# ============================================================================

set -e
echo "=== Deploying Traffic Mirroring Example ==="

# Step 1: Create namespace with Istio sidecar injection
kubectl apply -f namespace.yaml

# Step 2: Deploy httpbin v1 (production) and v2 (canary) + Service
kubectl apply -f deployment.yaml

# Step 3: Wait for all pods (v1 + v2) to be Ready
kubectl wait --for=condition=Ready pods --all -n mirror-demo --timeout=120s

# Step 4: Define v1/v2 subsets via DestinationRule
kubectl apply -f destination-rule.yaml

# Step 5: Apply VirtualService with mirroring configuration
# Routes 100% traffic to v1, mirrors 100% to v2
kubectl apply -f virtual-service.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n mirror-demo
