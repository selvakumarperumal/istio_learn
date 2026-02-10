#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the Egress Traffic Control demo
# ============================================================================
# Deploys a sleep pod (client) and registers httpbin.org as a known
# external service via ServiceEntry.
#
# WHAT THIS DEMONSTRATES:
#   Without ServiceEntry: External traffic works but has no Istio features
#   With ServiceEntry: External traffic gets metrics, tracing, and policies
#
# AFTER DEPLOYMENT:
#   Run ./test.sh to verify external requests through the ServiceEntry
# ============================================================================

set -e
echo "=== Deploying Egress Traffic Example ==="

# Step 1: Create namespace with Istio sidecar injection
kubectl apply -f namespace.yaml

# Step 2: Deploy sleep pod (client for external requests)
kubectl apply -f deployment.yaml

# Step 3: Wait for pod to be Ready
kubectl wait --for=condition=Ready pods --all -n egress-demo --timeout=120s

# Step 4: Register httpbin.org as a known external service
kubectl apply -f serviceentry.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n egress-demo
