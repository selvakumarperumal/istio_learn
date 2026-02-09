#!/bin/bash
echo "=== Retries and Timeouts Test ==="

NODE_PORT=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
MINIKUBE_IP=$(minikube ip)
GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"

echo -e "\n1. Testing timeout (delay > timeout should fail):"
echo "   Requesting /delay/15 with 10s timeout..."
time curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Host: httpbin.example.com" "$GATEWAY_URL/delay/15"

echo -e "\n2. Testing success (delay < timeout):"
echo "   Requesting /delay/1 (1s delay, 10s timeout)..."
time curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Host: httpbin.example.com" "$GATEWAY_URL/delay/1"

echo -e "\n3. Testing retries (status/503 returns 503):"
echo "   Retries should be attempted but all fail..."
curl -s -H "Host: httpbin.example.com" "$GATEWAY_URL/status/503"
echo ""
