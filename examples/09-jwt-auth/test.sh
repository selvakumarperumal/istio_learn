#!/bin/bash
echo "=== JWT Authentication Test ==="

NODE_PORT=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
MINIKUBE_IP=$(minikube ip)
GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"

# Sample JWT from Istio (valid token for testing)
TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6IkRIRmJwb0lVcXJZOHQyenBBMnFYZkNtcjVWTzVaRXI0UnpIVV8tZW52dlEiLCJ0eXAiOiJKV1QifQ.eyJleHAiOjQ2ODU5ODk3MDAsImZvbyI6ImJhciIsImlhdCI6MTUzMjM4OTcwMCwiaXNzIjoidGVzdGluZ0BzZWN1cmUuaXN0aW8uaW8iLCJzdWIiOiJ0ZXN0aW5nQHNlY3VyZS5pc3Rpby5pbyJ9.CfNnxWP2tcnR9q0vxyxweaF3ovQYHYZl82hAUsn21bwQd9zP7c-LS9qd_vpdLG4Tn1A15NxfCjp5f7QNBUo-KC9PJqYpgGbaXhaGx7bEdFWjcwv3nZzvc7M__ZpaCERdwU7igUmJqYGBYQ51vr2njU9ZimyKkfDe3axcyiBZde7G6dabliUosJvvKOPcKIWPccCgefSj_GNfwIip3-SsFdlR7BtbVUcqR-yv-XOxJ3Uc1MI0tz3uMiiZcyPV7sNCU4KRnemRIMHVOfuvHsU60_GhGbiSFzgPTAa9WTltbnarTbxudb_YEOx12JiwYToeX0DCPb43W1tzIBxgm8NxUg"

echo "Using Gateway: $GATEWAY_URL"

echo -e "\n1. Request WITHOUT token (should fail with 403):"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$GATEWAY_URL/headers"

echo -e "\n2. Request WITH valid token (should succeed with 200):"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Authorization: Bearer $TOKEN" "$GATEWAY_URL/headers"

echo -e "\n3. Request WITH invalid token (should fail with 401):"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Authorization: Bearer invalid-token" "$GATEWAY_URL/headers"
