#!/bin/bash
# ============================================================================
# test.sh - Test all fault injection scenarios
# ============================================================================
# Tests three fault injection modes:
#   1. DELAY: 50% of requests delayed by 5 seconds
#   2. ABORT: 50% of requests return HTTP 503
#   3. COMBINED: 20% abort + 30% delay on remaining
#
# HOW IT WORKS:
#   Before each test, ALL existing fault VirtualServices are deleted
#   to prevent conflicts, then the correct one is applied.
#
# PREREQUISITES:
#   - ./deploy-all.sh has been run
#   - minikube is running
# ============================================================================

set -e

echo "=== Fault Injection Test ==="

# ────────────────────────────────────────────────────────────────────────────
# Determine Gateway URL (Gateway API)
# ────────────────────────────────────────────────────────────────────────────
GATEWAY_URL=""

GATEWAY_IP=$(kubectl get gateway httpbin-gateway -n fault-demo -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)

if [ -n "$GATEWAY_IP" ]; then
    GATEWAY_URL="http://$GATEWAY_IP"
    echo "Using Gateway API IP: $GATEWAY_URL"
else
    # Fallback: Get the auto-provisioned gateway Service via NodePort (Minikube)
    GW_SVC=$(kubectl get svc -n fault-demo -l gateway.networking.k8s.io/gateway-name=httpbin-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    NODE_PORT=$(kubectl get svc -n fault-demo "$GW_SVC" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
    MINIKUBE_IP=$(minikube ip 2>/dev/null)
    if [ -n "$NODE_PORT" ] && [ -n "$MINIKUBE_IP" ]; then
        GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"
        echo "Using NodePort: $GATEWAY_URL"
    else
        echo "ERROR: Could not determine gateway URL"
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Helper: Remove ALL fault VirtualServices to prevent conflicts
# ─────────────────────────────────────────────────────────────────────────────
cleanup_vs() {
    kubectl delete vs httpbin-delay httpbin-abort httpbin-combined -n fault-demo --ignore-not-found 2>/dev/null
    sleep 2  # Allow Envoy to pick up the change
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: Send test requests and measure response time + status code
# ─────────────────────────────────────────────────────────────────────────────
send_requests() {
    local COUNT=${1:-10}
    for i in $(seq 1 $COUNT); do
        START=$(date +%s%N)
        CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Host: httpbin.example.com" \
            --max-time 10 \
            "$GATEWAY_URL/get" 2>/dev/null)
        END=$(date +%s%N)
        # Calculate duration in seconds with 1 decimal
        DURATION_MS=$(( (END - START) / 1000000 ))
        DURATION_S=$(echo "scale=1; $DURATION_MS / 1000" | bc)

        if [ "$CODE" == "503" ]; then
            echo "  Request $i: HTTP $CODE  ${DURATION_S}s  ← ABORTED"
        elif (( DURATION_MS > 2000 )); then
            echo "  Request $i: HTTP $CODE  ${DURATION_S}s  ← DELAYED"
        else
            echo "  Request $i: HTTP $CODE  ${DURATION_S}s"
        fi
    done
}

# ═════════════════════════════════════════════════════════════════════════════
# TEST 1: Delay Injection (50% chance of 5s delay)
# ═════════════════════════════════════════════════════════════════════════════
echo -e "\n────────────────────────────────────────────────"
echo "TEST 1: DELAY INJECTION (fault-delay.yaml)"
echo "────────────────────────────────────────────────"
echo "Config: 50% of requests delayed by 5 seconds"
echo "Expected: ~half take ~5s, half are instant, all HTTP 200"
echo ""

cleanup_vs
kubectl apply -f fault-delay.yaml
echo "Waiting for config to propagate..."
sleep 3

send_requests 6

# ═════════════════════════════════════════════════════════════════════════════
# TEST 2: Abort Injection (50% chance of HTTP 503)
# ═════════════════════════════════════════════════════════════════════════════
echo -e "\n────────────────────────────────────────────────"
echo "TEST 2: ABORT INJECTION (fault-abort.yaml)"
echo "────────────────────────────────────────────────"
echo "Config: 50% of requests return HTTP 503"
echo "Expected: ~half return 503, half return 200, all fast"
echo ""

cleanup_vs
kubectl apply -f fault-abort.yaml
echo "Waiting for config to propagate..."
sleep 3

send_requests 6

# ═════════════════════════════════════════════════════════════════════════════
# TEST 3: Combined Injection (20% abort + 30% delay)
# ═════════════════════════════════════════════════════════════════════════════
echo -e "\n────────────────────────────────────────────────"
echo "TEST 3: COMBINED INJECTION (fault-combined.yaml)"
echo "────────────────────────────────────────────────"
echo "Config: 20% abort (503) + 30% delay (3s) on remaining"
echo "Expected: mix of fast 200s, slow 200s (~3s), and 503s"
echo ""

cleanup_vs
kubectl apply -f fault-combined.yaml
echo "Waiting for config to propagate..."
sleep 3

send_requests 10

# ═════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════════════════════
echo -e "\n════════════════════════════════════════════════"
echo "SUMMARY"
echo "════════════════════════════════════════════════"
echo "✓ Test 1 (Delay):    ~50% should show ~5s delay"
echo "✓ Test 2 (Abort):    ~50% should show HTTP 503"
echo "✓ Test 3 (Combined): Mix of delays + aborts"
echo ""
echo "To switch fault type manually:"
echo "  kubectl apply -f fault-delay.yaml"
echo "  kubectl apply -f fault-abort.yaml"
echo "  kubectl apply -f fault-combined.yaml"
