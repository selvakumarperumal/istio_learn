#!/bin/bash
# ============================================================================
# test.sh - Test and verify fault injection is working
# ============================================================================
# WHAT THIS SCRIPT DOES:
#   1. Discovers the Istio Ingress Gateway URL (NodePort + Minikube IP)
#   2. Sends 5 HTTP requests to httpbin through the gateway
#   3. Measures response time and HTTP status code for each request
#   4. Prints results so you can observe fault injection effects
#
# EXPECTED RESULTS:
#   With fault-delay.yaml applied:
#     - ~50% of requests should take ~5 seconds (delayed)
#     - ~50% of requests should complete in <1 second (no fault)
#     - All requests should return HTTP 200
#
#   With fault-abort.yaml applied:
#     - ~50% of requests should return HTTP 503 (aborted)
#     - ~50% of requests should return HTTP 200 (passed through)
#     - All requests should complete quickly (aborts are immediate)
#
#   With fault-combined.yaml applied:
#     - ~20% of requests → HTTP 503 (aborted, fast)
#     - ~24% of requests → HTTP 200 (delayed ~3s)
#     - ~56% of requests → HTTP 200 (no fault, fast)
#
# PREREQUISITES:
#   - ./deploy-all.sh has been run successfully
#   - minikube is running (for IP and NodePort discovery)
#   - curl and bc are installed
#
# USAGE:
#   ./test.sh
# ============================================================================

echo "=== Fault Injection Test ==="

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Discover the Gateway URL
# ─────────────────────────────────────────────────────────────────────────────
# The Istio Ingress Gateway is exposed as a NodePort service in Minikube.
# We need the NodePort number and the Minikube VM's IP to construct the URL.
#
# For cloud clusters (GKE, EKS), you'd use a LoadBalancer IP instead:
#   GATEWAY_URL=$(kubectl get svc -n istio-ingress istio-ingressgateway \
#     -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# ─────────────────────────────────────────────────────────────────────────────
NODE_PORT=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null)
MINIKUBE_IP=$(minikube ip 2>/dev/null)
GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"

echo "Using: $GATEWAY_URL"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Send test requests and measure results
# ─────────────────────────────────────────────────────────────────────────────
# For each request, we measure:
#   - HTTP status code: 200 = success, 503 = aborted by fault injection
#   - Response time: Fast (<1s) = no delay, Slow (~5s) = delay injected
#
# The Host header is required because the Gateway is configured to route
# traffic based on the hostname "httpbin.example.com"
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n=== Testing Delay Injection (5 requests) ==="
echo "Some requests should take ~5s, others should be fast"
for i in {1..5}; do
    START=$(date +%s.%N)
    RESULT=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.example.com" "$GATEWAY_URL/get" 2>/dev/null)
    END=$(date +%s.%N)
    DURATION=$(echo "$END - $START" | bc)
    echo "  Request $i: HTTP $RESULT (${DURATION}s)"
done

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: Show how to switch to abort injection for further testing
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n=== To test abort injection ==="
echo "kubectl apply -f fault-abort.yaml"
echo "Then run: curl -v -H 'Host: httpbin.example.com' $GATEWAY_URL/get"
echo "Some requests should return HTTP 503"
