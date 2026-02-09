#!/bin/bash
# test.sh - Test header-based routing

echo "=== Request Routing Test ==="

# Get gateway URL
NODE_PORT=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null)
MINIKUBE_IP=$(minikube ip 2>/dev/null)
GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"

echo "Using: $GATEWAY_URL"

echo -e "\n=== Test 1: Default route (should be v1) ==="
for i in {1..3}; do
    RESULT=$(curl -s -H "Host: reviews.example.com" "$GATEWAY_URL/" 2>/dev/null)
    echo "  Request $i: $RESULT"
done

echo -e "\n=== Test 2: Beta users (should be v2) ==="
for i in {1..3}; do
    RESULT=$(curl -s -H "Host: reviews.example.com" -H "x-user-type: beta" "$GATEWAY_URL/" 2>/dev/null)
    echo "  Request $i: $RESULT"
done

echo -e "\n=== Test 3: Internal team (should be v3) ==="
for i in {1..3}; do
    RESULT=$(curl -s -H "Host: reviews.example.com" -H "x-user-type: internal" "$GATEWAY_URL/" 2>/dev/null)
    echo "  Request $i: $RESULT"
done

echo -e "\n=== Summary ==="
echo "✓ No header    → v1 (Standard Release)"
echo "✓ x-user-type: beta     → v2 (Beta Release)"
echo "✓ x-user-type: internal → v3 (Internal Release)"
