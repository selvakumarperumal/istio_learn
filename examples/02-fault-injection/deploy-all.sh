#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the complete Fault Injection demo environment
# ============================================================================
# WHAT THIS SCRIPT DOES:
#   1. Creates the "fault-demo" namespace with Istio sidecar injection enabled
#   2. Deploys the httpbin application (Deployment + Service)
#   3. Waits for all pods to be Ready (including Envoy sidecar)
#   4. Configures the Istio Ingress Gateway for external access
#   5. Applies the delay fault injection VirtualService by default
#
# PREREQUISITES:
#   - Kubernetes cluster running (e.g., minikube, kind, GKE)
#   - Istio installed with ingress gateway deployed
#   - kubectl configured to access the cluster
#   - Run from this directory (02-fault-injection/)
#
# USAGE:
#   ./deploy-all.sh
#
# AFTER DEPLOYMENT:
#   - Run ./test.sh to verify fault injection is working
#   - Switch fault types:
#       kubectl apply -f fault-abort.yaml     # Switch to abort faults
#       kubectl apply -f fault-combined.yaml  # Switch to combined faults
#       kubectl apply -f fault-delay.yaml     # Switch back to delay faults
#   - Run ./cleanup.sh to remove everything
# ============================================================================

set -e # Exit immediately if any command fails

echo "=== Deploying Fault Injection Example ==="

# Step 1: Create the namespace with istio-injection=enabled label
# This ensures all pods get Envoy sidecar proxies automatically
echo -e "\n1. Creating namespace..."
kubectl apply -f namespace.yaml

# Step 2: Deploy httpbin application (Deployment + Service)
# The Deployment creates an httpbin pod; the Service exposes it on port 80
echo -e "\n2. Deploying httpbin..."
kubectl apply -f deployment.yaml

# Step 3: Wait for pods to become Ready
# This includes waiting for the Envoy sidecar container to initialize
# The sidecar must be running before fault injection rules can take effect
echo -e "\n3. Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n fault-demo --timeout=120s

# Step 4: Apply the Gateway resource
# This configures the Istio Ingress Gateway to accept traffic for httpbin
echo -e "\n4. Applying gateway..."
kubectl apply -f gateway.yaml

# Step 5: Clean up any existing fault VirtualServices to prevent conflicts
# IMPORTANT: Only ONE fault VirtualService should exist at a time!
# Multiple VirtualServices targeting the same host cause unpredictable routing.
echo -e "\n5. Removing any stale fault VirtualServices..."
kubectl delete vs httpbin-delay httpbin-abort httpbin-combined -n fault-demo --ignore-not-found 2>/dev/null

# Step 6: Apply delay injection as the default starting point
echo -e "\n6. Applying delay injection by default..."
kubectl apply -f fault-delay.yaml
echo ""
echo "Available fault types (apply only ONE at a time):"
echo "   kubectl apply -f fault-delay.yaml    # 50% × 5s delay"
echo "   kubectl apply -f fault-abort.yaml    # 50% × HTTP 503"
echo "   kubectl apply -f fault-combined.yaml # 20% abort + 30% delay"
echo ""
echo "⚠  Before switching, delete the current one first:"
echo "   kubectl delete vs <current-vs-name> -n fault-demo"

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n fault-demo
echo -e "\nRun ./test.sh to test fault injection"
