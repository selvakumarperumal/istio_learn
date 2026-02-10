#!/bin/bash
# ============================================================================
# test.sh - Test JWT authentication behavior
# ============================================================================
# TESTS:
#   1. No token → 403 Forbidden (AuthorizationPolicy rejects)
#   2. Valid token → 200 OK (JWT validated, access granted)
#   3. Invalid token → 401 Unauthorized (RequestAuthentication rejects)
#
# TOKEN USED:
#   Istio's sample JWT token with issuer "testing@secure.istio.io"
#   This token has a far-future expiration for testing purposes.
# ============================================================================

echo "=== JWT Authentication Test ==="

# Discover Gateway URL (Minikube NodePort)
NODE_PORT=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
MINIKUBE_IP=$(minikube ip)
GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"

# Sample JWT from Istio (valid token for testing)
# Claims: iss=testing@secure.istio.io, sub=testing@secure.istio.io
TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6IkRIRmJwb0lVcXJZOHQyenBBMnFYZkNtcjVWTzVaRXI0UnpIVV8tZW52dlEiLCJ0eXAiOiJKV1QifQ.eyJleHAiOjQ2ODU5ODk3MDAsImZvbyI6ImJhciIsImlhdCI6MTUzMjM4OTcwMCwiaXNzIjoidGVzdGluZ0BzZWN1cmUuaXN0aW8uaW8iLCJzdWIiOiJ0ZXN0aW5nQHNlY3VyZS5pc3Rpby5pbyJ9.CfNnxWP2tcnR9q0vxyxweaF3ovQYHYZl82hAUsn21bwQd9zP7c-LS9qd_vpdLG4Tn1A15NxfCjp5f7QNBUo-KC9PJqYpgGbaXhaGx7bEdFWjcwv3nZzvc7M__ZpaCERdwU7igUmJqYGBYQ51vr2njU9ZimyKkfDe3axcyiBZde7G6dabliUosJvvKOPcKIWPccCgefSj_GNfwIip3-SsFdlR7BtbVUcqR-yv-XOxJ3Uc1MI0tz3uMiiZcyPV7sNCU4KRnemRIMHVOfuvHsU60_GhGbiSFzgPTAa9WTltbnarTbxudb_YEOx12JiwYToeX0DCPb43W1tzIBxgm8NxUg"

echo "Using Gateway: $GATEWAY_URL"

# ─────────────────────────────────────────────────────────────────────────────
# TEST 1: No token → AuthorizationPolicy rejects with 403
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n1. Request WITHOUT token (should fail with 403):"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$GATEWAY_URL/headers"

# ─────────────────────────────────────────────────────────────────────────────
# TEST 2: Valid token → RequestAuthentication validates, access granted
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n2. Request WITH valid token (should succeed with 200):"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Authorization: Bearer $TOKEN" "$GATEWAY_URL/headers"

# ─────────────────────────────────────────────────────────────────────────────
# TEST 3: Invalid token → RequestAuthentication rejects with 401
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n3. Request WITH invalid token (should fail with 401):"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Authorization: Bearer invalid-token" "$GATEWAY_URL/headers"
