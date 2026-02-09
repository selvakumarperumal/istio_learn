#!/bin/bash
# test.sh - Test fault injection

echo "=== Fault Injection Test ==="

NODE_PORT=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null)
MINIKUBE_IP=$(minikube ip 2>/dev/null)
GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"

echo "Using: $GATEWAY_URL"

echo -e "\n=== Testing Delay Injection (5 requests) ==="
echo "Some requests should take ~5s, others should be fast"
for i in {1..5}; do
    START=$(date +%s.%N)
    RESULT=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.example.com" "$GATEWAY_URL/get" 2>/dev/null)
    END=$(date +%s.%N)
    DURATION=$(echo "$END - $START" | bc)
    echo "  Request $i: HTTP $RESULT (${DURATION}s)"
done

echo -e "\n=== To test abort injection ==="
echo "kubectl apply -f fault-abort.yaml"
echo "Then run: curl -v -H 'Host: httpbin.example.com' $GATEWAY_URL/get"
echo "Some requests should return HTTP 503"
