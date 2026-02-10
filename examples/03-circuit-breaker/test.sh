#!/bin/bash
# ============================================================================
# test.sh - Test and verify circuit breaker behavior
# ============================================================================
# WHAT THIS SCRIPT DOES:
#   1. Sends a SINGLE request to verify httpbin is healthy
#   2. Sends 20 CONCURRENT requests (3 at a time) to trigger the breaker
#
# EXPECTED RESULTS:
#   Step 1 (single request): Should succeed with HTTP 200
#   Step 2 (concurrent): With maxConnections=1 and 3 concurrent connections:
#     - Some requests succeed (HTTP 200) — these got through the limit
#     - Some requests fail (HTTP 503) — these were REJECTED by the breaker
#     - Look for "upstream_rq_pending_overflow" in Envoy stats
#
# FORTIO FLAGS EXPLAINED:
#   -c 3       : 3 concurrent connections (exceeds maxConnections=1)
#   -qps 0     : No rate limit, send as fast as possible
#   -n 20      : Total 20 requests
#   -loglevel Warning : Suppress verbose output, show only results
#
# PREREQUISITES:
#   - ./deploy-all.sh has been run successfully
#   - Both httpbin and fortio pods are Running
# ============================================================================

echo "=== Circuit Breaker Test ==="

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Get the fortio pod name for exec commands
# ─────────────────────────────────────────────────────────────────────────────
FORTIO_POD=$(kubectl get pods -n circuit-demo -l app=fortio -o jsonpath='{.items[0].metadata.name}')

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Single request — baseline test (should always succeed)
# ─────────────────────────────────────────────────────────────────────────────
# One request with one connection is within the circuit breaker limits
# (maxConnections=1, http1MaxPendingRequests=1), so this should pass.
echo -e "\n1. Single request (should work):"
kubectl exec -n circuit-demo "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio curl http://httpbin:80/get

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: Concurrent requests — trigger the circuit breaker!
# ─────────────────────────────────────────────────────────────────────────────
# With -c 3 (3 concurrent connections) but maxConnections=1:
#   - 1 connection goes through to httpbin
#   - 1 request waits in the pending queue (http1MaxPendingRequests=1)
#   - 1+ requests are REJECTED with 503 (queue full → overflow)
#
# The fortio output shows a summary like:
#   Code 200 : 12 (60%)
#   Code 503 :  8 (40%)  ← These were rejected by the circuit breaker!
echo -e "\n2. Concurrent requests (should trigger circuit breaker):"
echo "   Sending 20 requests with 3 concurrent connections..."
kubectl exec -n circuit-demo "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio load -c 3 -qps 0 -n 20 -loglevel Warning http://httpbin:80/get

echo -e "\n=== Results ==="
echo "If you see 'upstream_rq_pending_overflow' or HTTP 503 errors,"
echo "the circuit breaker is working!"
