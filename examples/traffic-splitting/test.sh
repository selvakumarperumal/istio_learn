#!/bin/bash
# test.sh - Test the traffic splitting

echo "=== Traffic Splitting Test ==="

# Try to get gateway URL
GATEWAY_URL=""

# Check if minikube tunnel is providing an external IP
EXTERNAL_IP=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
    GATEWAY_URL="http://$EXTERNAL_IP"
    echo "Using LoadBalancer IP: $GATEWAY_URL"
else
    # Try NodePort
    NODE_PORT=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null)
    MINIKUBE_IP=$(minikube ip 2>/dev/null)
    
    if [ -n "$NODE_PORT" ] && [ -n "$MINIKUBE_IP" ]; then
        GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"
        echo "Using NodePort: $GATEWAY_URL"
    else
        echo "ERROR: Could not determine gateway URL"
        echo "Try running: minikube tunnel (in another terminal)"
        exit 1
    fi
fi

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

echo -e "\n=== Results ==="
echo "v1 responses: $V1_COUNT ($(( V1_COUNT * 100 / 20 ))%)"
echo "v2 responses: $V2_COUNT ($(( V2_COUNT * 100 / 20 ))%)"
echo ""
echo "Expected: ~80% v1, ~20% v2"
