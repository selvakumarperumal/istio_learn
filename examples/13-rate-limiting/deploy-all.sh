#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the Rate Limiting demo
# ============================================================================
# Deploys httpbin and applies a local rate limit of 10 requests per minute.
# The EnvoyFilter uses the token bucket algorithm to control request rates.
#
# AFTER DEPLOYMENT:
#   Run ./test.sh to send 15 rapid requests (first 10 succeed, rest get 429)
# ============================================================================

set -e
echo "=== Deploying Rate Limiting Example ==="

# Step 1: Create namespace with Istio sidecar injection
kubectl apply -f namespace.yaml

# Step 2: Deploy httpbin (the service to be rate limited)
kubectl apply -f deployment.yaml

# Step 3: Wait for pods to be Ready (app + sidecar)
kubectl wait --for=condition=Ready pods --all -n ratelimit-demo --timeout=120s

# Step 4: Apply EnvoyFilter with rate limit configuration
# This inserts a local rate limit filter into httpbin's Envoy sidecar
kubectl apply -f envoyfilter.yaml

echo -e "\n=== Deployment Complete ==="
echo "Rate limit: 10 requests per minute"
kubectl get pods -n ratelimit-demo
