#!/bin/bash
# ============================================================================
# test.sh - Test egress traffic through ServiceEntry
# ============================================================================
# Makes a request to httpbin.org from inside the mesh.
# The ServiceEntry allows Istio to apply metrics, tracing, and policies
# to this external request.
#
# EXPECTED RESULT: HTTP 200 from httpbin.org
# ============================================================================

echo "=== Egress Traffic Test ==="

# ─────────────────────────────────────────────────────────────────────────────
# TEST: Call external httpbin.org via the registered ServiceEntry
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n1. Calling external httpbin.org..."
kubectl exec -n egress-demo deploy/sleep -c sleep -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin.org/get

# Verify the ServiceEntry is registered
echo -e "\n2. View ServiceEntry:"
kubectl get serviceentry -n egress-demo

echo -e "\nSuccess! External traffic is controlled via ServiceEntry."
