#!/bin/bash
# ============================================================================
# test.sh - Verify traffic mirroring is working
# ============================================================================
# HOW TO VERIFY:
#   1. Send a request to the httpbin service (routed to v1)
#   2. Check v2's access logs — you should see the mirrored request!
#   3. The mirrored request in v2 logs will have a "-shadow" Host header
#
# EXPECTED BEHAVIOR:
#   - v1 receives the request and returns a response
#   - v2 receives a COPY of the request (visible in its logs)
#   - The client only sees v1's response
# ============================================================================

echo "=== Traffic Mirroring Test ==="

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Send a request through v1 pod to the httpbin service
# ─────────────────────────────────────────────────────────────────────────────
# This request goes to v1 (production). Envoy automatically mirrors
# a copy to v2 (canary) in the background.
echo -e "\n1. Sending requests to v1..."
kubectl exec -n mirror-demo deploy/httpbin-v1 -c httpbin -- \
  curl -s http://httpbin/headers | head -5

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Check v2 logs for mirrored requests
# ─────────────────────────────────────────────────────────────────────────────
# The key evidence of mirroring is seeing requests in v2's logs that
# were NOT sent directly to v2. Look for the "-shadow" suffix in the
# Host header, which Istio adds to mirrored requests.
echo -e "\n2. Check v2 logs for mirrored requests:"
echo "   kubectl logs -n mirror-demo deploy/httpbin-v2 -c httpbin -f"
echo ""
echo "   You should see incoming requests even though we only called v1!"
