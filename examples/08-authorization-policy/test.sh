#!/bin/bash
# ============================================================================
# test.sh - Test Authorization Policy behavior
# ============================================================================
# Tests three scenarios:
#   1. Before any policy: All traffic allowed (default open)
#   2. After deny-all: All traffic blocked (403 Forbidden)
#   3. After allow-specific: Only sleep→httpbin GET allowed (200 OK)
#
# EXPECTED RESULTS:
#   Step 1: HTTP 200 (no policy → allowed)
#   Step 2: HTTP 403 (deny-all → blocked)
#   Step 3: HTTP 200 (allow-sleep → permitted for GET from sleep)
# ============================================================================

echo "=== Authorization Policy Test ==="

# ─────────────────────────────────────────────────────────────────────────────
# TEST 1: No policy applied — everything should work (default allow)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n1. Before any policy (should work):"
kubectl exec -n authz-demo deploy/sleep -c sleep -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin/get

# ─────────────────────────────────────────────────────────────────────────────
# TEST 2: Deny-all policy — blocks ALL traffic to httpbin
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n2. Apply deny-all policy:"
kubectl apply -f authz-deny-all.yaml
sleep 2 # Wait for policy to propagate to Envoy sidecars
kubectl exec -n authz-demo deploy/sleep -c sleep -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin/get
echo "   (Should be 403 Forbidden)"

# ─────────────────────────────────────────────────────────────────────────────
# TEST 3: Allow-specific policy — permits sleep→httpbin GET only
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n3. Apply allow-specific policy:"
kubectl apply -f authz-allow-specific.yaml
sleep 2 # Wait for policy propagation
kubectl exec -n authz-demo deploy/sleep -c sleep -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin/get
echo "   (Should be 200 OK)"
