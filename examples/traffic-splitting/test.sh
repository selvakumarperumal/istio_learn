#!/bin/bash
# ============================================================================
# test.sh - Test the 80/20 traffic splitting
# ============================================================================
# Sends 20 requests and counts how many go to v1 vs v2.
#
# EXPECTED RESULTS:
#   ~80% (16 out of 20) should go to v1
#   ~20% (4 out of 20) should go to v2
#
# NOTE: Results are probabilistic — small samples may deviate from
# exact percentages. Over more requests, results converge to 80/20.
# ============================================================================

echo "=== Traffic Splitting Test ==="

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Discover Gateway URL (try LoadBalancer IP first, then NodePort)
# ─────────────────────────────────────────────────────────────────────────────
GATEWAY_URL=""

GATEWAY_IP=$(kubectl get gateway reviews-gateway -n traffic-demo -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)

if [ -n "$GATEWAY_IP" ]; then
    GATEWAY_URL="http://$GATEWAY_IP"
    echo "Using Gateway API IP: $GATEWAY_URL"
else
    # Fallback: Get the auto-provisioned gateway Service via NodePort (Minikube)
    GW_SVC=$(kubectl get svc -n traffic-demo -l gateway.networking.k8s.io/gateway-name=reviews-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    NODE_PORT=$(kubectl get svc -n traffic-demo "$GW_SVC" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
    MINIKUBE_IP=$(minikube ip 2>/dev/null)
    if [ -n "$NODE_PORT" ] && [ -n "$MINIKUBE_IP" ]; then
        GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"
        echo "Using NodePort: $GATEWAY_URL"
    else
        echo "ERROR: Cannot determine gateway URL."
        echo "Ensure the gateway is running:"
        echo "  kubectl get gateway -n traffic-demo"
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Send 20 requests and count version distribution
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n=== Sending 20 requests ==="
echo "Expected: ~80% v1, ~20% v2"
echo ""

V1_COUNT=0
V2_COUNT=0

for i in {1..20}; do
    RESULT=$(curl -s -H "Host: reviews.example.com" "$GATEWAY_URL/version" 2>/dev/null)

    if [[ "$RESULT" == *"v1"* ]]; then
        ((V1_COUNT++))
        echo "  Request $i: v1"
    elif [[ "$RESULT" == *"v2"* ]]; then
        ((V2_COUNT++))
        echo "  Request $i: v2 ★"
    else
        echo "  Request $i: ERROR - $RESULT"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: Show results summary
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n=== Results ==="
echo "v1 responses: $V1_COUNT ($(( V1_COUNT * 100 / 20 ))%)"
echo "v2 responses: $V2_COUNT ($(( V2_COUNT * 100 / 20 ))%)"
echo ""
echo "Expected: ~80% v1, ~20% v2"
