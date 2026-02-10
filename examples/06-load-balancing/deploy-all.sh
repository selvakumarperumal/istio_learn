#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the Load Balancing demo
# ============================================================================
# Deploys httpbin with 3 replicas and applies Round Robin as the default
# load balancing algorithm. You can then switch algorithms using:
#   kubectl apply -f lb-random.yaml          # Random selection
#   kubectl apply -f lb-least-conn.yaml      # Least connections (adaptive)
#   kubectl apply -f lb-consistent-hash.yaml # Sticky sessions (hash-based)
#
# NOTE: Apply only ONE DestinationRule at a time. Each new one replaces
# the previous algorithm because they all target the same host.
# ============================================================================

set -e
echo "=== Deploying Load Balancing Example ==="

# Step 1: Create namespace with Istio sidecar injection
kubectl apply -f namespace.yaml

# Step 2: Deploy httpbin with 3 replicas + Service
kubectl apply -f deployment.yaml

# Step 3: Wait for all 3 pods to be Ready
kubectl wait --for=condition=Ready pods --all -n lb-demo --timeout=120s

# Step 4: Apply Round Robin as the default algorithm
echo -e "\nApplying Round Robin (default)..."
kubectl apply -f lb-round-robin.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n lb-demo
echo -e "\nTo test different algorithms:"
echo "  kubectl apply -f lb-random.yaml"
echo "  kubectl apply -f lb-least-conn.yaml"
echo "  kubectl apply -f lb-consistent-hash.yaml"
