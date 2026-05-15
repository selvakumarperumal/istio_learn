#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the Header-Based Request Routing demo
# ============================================================================
# Deploys 3 versions of the reviews app and configures Istio to route
# traffic based on the x-user-type HTTP header.
#
# WHAT GETS DEPLOYED:
#   1. Namespace with Istio sidecar injection
#   2. Deployments: reviews-v1, reviews-v2, reviews-v3
#   3. Service: reviews-svc (selects all versions via app=reviews label)
#   4. DestinationRule: defines v1, v2, v3 subsets
#   5. HTTPRoute: header-based routing rules (Gateway API)
#   6. Gateway: external access via Kubernetes Gateway API
#
# AFTER DEPLOYMENT:
#   Run ./test.sh to verify header-based routing
# ============================================================================

set -e

echo "=== Deploying Request Routing Example ==="

# Step 1: Create namespace with Istio sidecar injection
echo -e "\n1. Creating namespace..."
kubectl apply -f namespace.yaml

# Step 2: Deploy all three versions (v1=stable, v2=beta, v3=internal)
echo -e "\n2. Deploying v1, v2, v3..."
kubectl apply -f deployment.yaml

# Step 3: Create service that selects all versions (app=reviews)
echo -e "\n3. Creating service..."
kubectl apply -f service.yaml

# Step 4: Wait for all pods to be Ready
echo -e "\n4. Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n routing-demo --timeout=120s

# Step 5: Apply Istio routing configuration
# DestinationRule defines subsets (v1, v2, v3)
# VirtualService defines header-based routing rules
# Gateway enables external access
echo -e "\n5. Applying Istio resources..."
kubectl apply -f destination-rule.yaml
kubectl apply -f httproute.yaml
kubectl apply -f gateway.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n routing-demo
echo -e "\nRun ./test.sh to verify routing"
