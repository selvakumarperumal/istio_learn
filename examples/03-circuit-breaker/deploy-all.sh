#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy the complete Circuit Breaker demo environment
# ============================================================================
# WHAT THIS SCRIPT DOES:
#   1. Creates the "circuit-demo" namespace with Istio sidecar injection
#   2. Deploys httpbin (the service protected by the circuit breaker)
#   3. Deploys fortio (load testing tool to trigger the circuit breaker)
#   4. Waits for all pods to be Ready (including Envoy sidecars)
#   5. Applies the DestinationRule with circuit breaker configuration
#
# DEPLOYMENT ORDER MATTERS:
#   The DestinationRule is applied LAST because:
#   - Pods must be running before circuit breaker rules take effect
#   - Envoy sidecars need to be initialized to enforce the rules
#   - Applying rules to non-existent services has no effect
#
# PREREQUISITES:
#   - Kubernetes cluster running with Istio installed
#   - kubectl configured to access the cluster
#
# USAGE:
#   ./deploy-all.sh
#   ./test.sh          # Test circuit breaker behavior
#   ./cleanup.sh       # Remove everything
# ============================================================================

set -e # Exit immediately if any command fails

echo "=== Deploying Circuit Breaker Example ==="

# Step 1: Create namespace with Istio sidecar injection enabled
echo -e "\n1. Creating namespace..."
kubectl apply -f namespace.yaml

# Step 2: Deploy httpbin — the target service protected by the circuit breaker
echo -e "\n2. Deploying httpbin..."
kubectl apply -f deployment.yaml

# Step 3: Deploy fortio — the load generator used to overwhelm the circuit breaker
echo -e "\n3. Deploying fortio client..."
kubectl apply -f fortio-client.yaml

# Step 4: Wait for all pods (httpbin + fortio) to be Ready
# "Ready" here means both the app container AND the Envoy sidecar are running
echo -e "\n4. Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n circuit-demo --timeout=120s

# Step 5: Apply the DestinationRule (circuit breaker configuration)
# This configures Envoy to limit connections and detect outliers
echo -e "\n5. Applying circuit breaker..."
kubectl apply -f destination-rule.yaml

echo -e "\n=== Deployment Complete ==="
kubectl get pods -n circuit-demo
echo -e "\nRun ./test.sh to test circuit breaker"
