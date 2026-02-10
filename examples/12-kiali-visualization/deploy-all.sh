#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy Kiali Service Mesh Visualization
# ============================================================================
# Installs Kiali, Istio's service mesh visualization dashboard, into the
# istio-system namespace.
#
# WHAT IS KIALI?
#   Kiali provides a graphical view of your service mesh:
#   - Service topology graph (real-time traffic flow)
#   - Health indicators for services, workloads, and apps
#   - Traffic metrics (request rate, error rate, latency)
#   - mTLS status (lock icon shows encrypted connections)
#   - Configuration validation (detects misconfigurations)
#
# PREREQUISITES:
#   Kiali works best with Prometheus installed (for metrics data).
#   Run ../11-metrics-prometheus/deploy-all.sh first.
#
# AFTER DEPLOYMENT:
#   kubectl port-forward svc/kiali 20001:20001 -n istio-system
#   Open http://localhost:20001
# ============================================================================

set -e
echo "=== Deploying Kiali ==="

# Step 1: Install Kiali (service mesh dashboard)
echo -e "\n1. Installing Kiali..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# Step 2: Wait for Kiali pod to be Ready
echo -e "\n2. Waiting for Kiali..."
kubectl wait --for=condition=Ready pods -l app=kiali -n istio-system --timeout=120s

echo -e "\n=== Deployment Complete ==="
echo "Access Kiali:"
echo "  kubectl port-forward svc/kiali 20001:20001 -n istio-system"
echo "  Open http://localhost:20001"
