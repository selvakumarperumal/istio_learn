#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the Traffic Splitting (Canary) demo
# ============================================================================
# Deploys v1 (3 replicas) and v2 (1 replica) of the reviews app, then
# configures Istio to split traffic 80/20 between them.
#
# WHAT GETS DEPLOYED:
#   1. Namespace with Istio sidecar injection
#   2. Deployment v1: 3 replicas (stable production version)
#   3. Deployment v2: 1 replica (canary/new version)
#   4. Service: reviews-svc (selects all versions via app=myapp label)
#   5. DestinationRule: defines v1 and v2 subsets with traffic policies
#   6. VirtualService: 80/20 traffic split with retries and timeouts
#   7. Gateway: external access via Istio Ingress Gateway
#
# AFTER DEPLOYMENT:
#   Run ./test.sh to verify 80/20 traffic distribution
# ============================================================================

set -e

echo "=== Deploying Traffic Splitting Example ==="

# Step 1: Create namespace with Istio sidecar injection
echo -e "\n1. Creating namespace..."
kubectl apply -f namespace.yaml

# Step 2: Deploy v1 (stable, 3 replicas — receives 80% of traffic)
echo -e "\n2. Deploying v1 (3 replicas)..."
kubectl apply -f deployment-v1.yaml

# Step 3: Deploy v2 (canary, 1 replica — receives 20% of traffic)
echo -e "\n3. Deploying v2 (1 replica)..."
kubectl apply -f deployment-v2.yaml

# Step 4: Create service that selects all versions
echo -e "\n4. Creating service..."
kubectl apply -f service.yaml

# Step 5: Wait for all pods to be Ready
echo -e "\n5. Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n traffic-demo --timeout=120s

# Step 6: Apply DestinationRule (defines v1/v2 subsets)
echo -e "\n6. Applying DestinationRule..."
kubectl apply -f destination-rule.yaml

# Step 7: Apply VirtualService (80/20 traffic split)
echo -e "\n7. Applying VirtualService (80/20 split)..."
kubectl apply -f virtual-service.yaml

# Step 8: Apply Gateway (external access)
echo -e "\n8. Applying Gateway..."
kubectl apply -f gateway.yaml

echo -e "\n=== Deployment Complete ==="
echo -e "\nPods:"
kubectl get pods -n traffic-demo

echo -e "\nServices:"
kubectl get svc -n traffic-demo

echo -e "\nIstio resources:"
kubectl get virtualservice,destinationrule,gateway -n traffic-demo

echo -e "\n=== Testing Instructions ==="
echo "1. Get gateway URL: minikube service istio-ingressgateway -n istio-ingress --url"
echo "2. Test: curl -H 'Host: reviews.example.com' <URL>/version"
echo "3. Or run: ./test.sh"
