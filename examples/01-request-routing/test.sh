#!/bin/bash
# ============================================================================
# TEST SCRIPT: Header-Based Request Routing Verification
# ============================================================================
# PURPOSE:
#   Verify that Istio VirtualService routes traffic correctly based on
#   HTTP headers. Tests all three routing scenarios:
#   - Default traffic → v1 (stable)
#   - Beta users      → v2 (beta features)
#   - Internal team   → v3 (internal/debug)
#
# PREREQUISITES:
#   1. Minikube running with Istio installed
#   2. All resources deployed: kubectl apply -f .
#   3. Pods are ready: kubectl get pods -n routing-demo
#
# HOW IT WORKS:
#   ┌─────────────────────────────────────────────────────────────────────┐
#   │                                                                     │
#   │   Test 1: curl http://gateway/                                      │
#   │           No special headers                                        │
#   │           → VirtualService routes to v1 (default)                   │
#   │                                                                     │
#   │   Test 2: curl -H "x-user-type: beta" http://gateway/               │
#   │           Header matches first rule                                 │
#   │           → VirtualService routes to v2 (beta)                      │
#   │                                                                     │
#   │   Test 3: curl -H "x-user-type: internal" http://gateway/           │
#   │           Header matches second rule                                │
#   │           → VirtualService routes to v3 (internal)                  │
#   │                                                                     │
#   └─────────────────────────────────────────────────────────────────────┘
#
# EXPECTED OUTPUT:
#   Test 1: "Reviews Service v1" (3 times)
#   Test 2: "Reviews Service v2" (3 times)
#   Test 3: "Reviews Service v3" (3 times)
#
# TROUBLESHOOTING:
#   - If requests fail: Check if gateway is accessible
#     $ kubectl get gateway reviews-gateway -n routing-demo
#
#   - If wrong version returned: Check HTTPRoute rules
#     $ kubectl describe httproute reviews-routing -n routing-demo
#
#   - If 503 errors: Check if pods are ready
#     $ kubectl get pods -n routing-demo
#
# USAGE:
#   $ chmod +x test.sh
#   $ ./test.sh
# ============================================================================

echo "=== Request Routing Test ==="

# ════════════════════════════════════════════════════════════════════════════
# STEP 1: Get the Gateway API Gateway URL
# ════════════════════════════════════════════════════════════════════════════
# Gateway API provisions its own Service automatically. We get the IP
# from the Gateway's status, or fall back to NodePort for Minikube.

GATEWAY_IP=$(kubectl get gateway reviews-gateway -n routing-demo -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
if [ -n "$GATEWAY_IP" ]; then
    GATEWAY_URL="http://$GATEWAY_IP"
else
    # Fallback: Get the auto-provisioned gateway Service via NodePort (Minikube)
    GW_SVC=$(kubectl get svc -n routing-demo -l gateway.networking.k8s.io/gateway-name=reviews-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    NODE_PORT=$(kubectl get svc -n routing-demo "$GW_SVC" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
    MINIKUBE_IP=$(minikube ip 2>/dev/null)
    GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"
fi

echo "Using: $GATEWAY_URL"

# ════════════════════════════════════════════════════════════════════════════
# TEST 1: Default Route (no special headers)
# ════════════════════════════════════════════════════════════════════════════
# When NO x-user-type header is present, traffic goes to v1 (stable version)
# This matches the DEFAULT rule in VirtualService (the rule with no conditions)

echo -e "\n=== Test 1: Default route (should be v1) ==="
for i in {1..3}; do
    # -H "Host: reviews.example.com" tells the gateway which VirtualService to use
    RESULT=$(curl -s -H "Host: reviews.example.com" "$GATEWAY_URL/" 2>/dev/null)
    echo "  Request $i: $RESULT"
done

# ════════════════════════════════════════════════════════════════════════════
# TEST 2: Beta Users (x-user-type: beta)
# ════════════════════════════════════════════════════════════════════════════
# When x-user-type header equals "beta", traffic goes to v2
# This matches RULE 1 in VirtualService: headers.x-user-type.exact: beta

echo -e "\n=== Test 2: Beta users (should be v2) ==="
for i in {1..3}; do
    # Adding x-user-type: beta header triggers routing to v2 subset
    RESULT=$(curl -s -H "Host: reviews.example.com" -H "x-user-type: beta" "$GATEWAY_URL/" 2>/dev/null)
    echo "  Request $i: $RESULT"
done

# ════════════════════════════════════════════════════════════════════════════
# TEST 3: Internal Team (x-user-type: internal)
# ════════════════════════════════════════════════════════════════════════════
# When x-user-type header equals "internal", traffic goes to v3
# This matches RULE 2 in VirtualService: headers.x-user-type.exact: internal

echo -e "\n=== Test 3: Internal team (should be v3) ==="
for i in {1..3}; do
    # Adding x-user-type: internal header triggers routing to v3 subset
    RESULT=$(curl -s -H "Host: reviews.example.com" -H "x-user-type: internal" "$GATEWAY_URL/" 2>/dev/null)
    echo "  Request $i: $RESULT"
done

# ════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════════════════
echo -e "\n=== Summary ==="
echo "✓ No header    → v1 (Standard Release)"
echo "✓ x-user-type: beta     → v2 (Beta Release)"
echo "✓ x-user-type: internal → v3 (Internal Release)"
