#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the JWT Authentication demo
# ============================================================================
# Deploys httpbin + Gateway API (Gateway + HTTPRoute), then applies JWT
# validation and enforcement.
#
# WHAT GETS DEPLOYED:
#   1. Namespace with Istio sidecar injection
#   2. httpbin Deployment + Service (the protected API)
#   3. Gateway + HTTPRoute (external access via Gateway API)
#   4. RequestAuthentication (validates JWT signature and claims)
#   5. AuthorizationPolicy (requires valid JWT for access)
#
# AFTER DEPLOYMENT:
#   Run ./test.sh to verify JWT token validation
# ============================================================================

set -e
echo "=== Deploying JWT Auth Example ==="

# Step 1: Create namespace with Istio sidecar injection
kubectl apply -f namespace.yaml

# Step 2: Deploy httpbin (the service to be protected)
kubectl apply -f deployment.yaml

# Step 3: Deploy Gateway API resources for external access
kubectl apply -f gateway.yaml

# Step 4: Wait for pods to be Ready
kubectl wait --for=condition=Ready pods --all -n jwt-demo --timeout=120s

# Step 5: Apply JWT authentication and authorization
# RequestAuthentication → validates JWT tokens
# AuthorizationPolicy → requires valid JWT (rejects unauthenticated requests)
echo -e "\nApplying JWT authentication..."
kubectl apply -f requestauthentication.yaml
kubectl apply -f authorizationpolicy.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n jwt-demo
echo -e "\nRun ./test.sh to test JWT authentication"
