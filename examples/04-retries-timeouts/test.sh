#!/bin/bash
# ============================================================================
# test.sh - Test retry and timeout behavior
# ============================================================================
# TEST CASES:
#   1. Timeout test: /delay/15 with 10s timeout → should fail after ~10s
#   2. Success test: /delay/1 with 10s timeout → should succeed quickly
#   3. Retry test: /status/503 → retries 3 times, all fail → returns 503
#
# WHAT TO LOOK FOR:
#   - Test 1: HTTP 504 (Gateway Timeout) after ~10s, NOT after 15s
#   - Test 2: HTTP 200 after ~1s
#   - Test 3: HTTP 503, but Envoy retried 3 times behind the scenes
# ============================================================================

echo "=== Retries and Timeouts Test ==="

# Get Gateway API URL
GATEWAY_IP=$(kubectl get gateway httpbin-gateway -n retry-demo -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
if [ -n "$GATEWAY_IP" ]; then
    GATEWAY_URL="http://$GATEWAY_IP"
else
    GW_SVC=$(kubectl get svc -n retry-demo -l gateway.networking.k8s.io/gateway-name=httpbin-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    NODE_PORT=$(kubectl get svc -n retry-demo "$GW_SVC" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
    MINIKUBE_IP=$(minikube ip 2>/dev/null)
    GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TEST 1: Timeout — request takes 15s but timeout is 10s
# ─────────────────────────────────────────────────────────────────────────────
# The /delay/15 endpoint makes httpbin wait 15 seconds before responding.
# Since our VirtualService timeout is 10s, Envoy will cancel the request
# after 10s and return HTTP 504 Gateway Timeout.
echo -e "\n1. Testing timeout (delay > timeout should fail):"
echo "   Requesting /delay/15 with 10s timeout..."
time curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Host: httpbin.example.com" "$GATEWAY_URL/delay/15"

# ─────────────────────────────────────────────────────────────────────────────
# TEST 2: Success — request takes 1s, well within 10s timeout
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n2. Testing success (delay < timeout):"
echo "   Requesting /delay/1 (1s delay, 10s timeout)..."
time curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Host: httpbin.example.com" "$GATEWAY_URL/delay/1"

# ─────────────────────────────────────────────────────────────────────────────
# TEST 3: Retries — /status/503 always returns 503, triggering retries
# ─────────────────────────────────────────────────────────────────────────────
# Since /status/503 ALWAYS returns 503, all 3 retries will also fail.
# The client receives 503 after 4 total attempts (1 initial + 3 retries).
# You can verify retries happened by checking Envoy access logs:
#   kubectl logs <pod> -c istio-proxy -n retry-demo
echo -e "\n3. Testing retries (status/503 returns 503):"
echo "   Retries should be attempted but all fail..."
curl -s -H "Host: httpbin.example.com" "$GATEWAY_URL/status/503"
echo ""
