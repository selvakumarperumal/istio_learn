#!/bin/bash
# ============================================================================
# test.sh - Test rate limiting behavior
# ============================================================================
# Sends 15 rapid requests. With a 10 req/min token bucket:
#   - Requests 1-10: HTTP 200 (tokens available)
#   - Requests 11-15: HTTP 429 Too Many Requests (tokens exhausted)
#
# The 429 response includes header: x-local-rate-limit: true
# Wait 60 seconds for tokens to refill, then retry.
# ============================================================================

echo "=== Rate Limiting Test ==="
echo "Sending 15 rapid requests (limit is 10/min)..."

for i in {1..15}; do
    RESULT=$(kubectl exec -n ratelimit-demo deploy/httpbin -c httpbin -- \
      curl -s -o /dev/null -w "%{http_code}" http://localhost:80/get 2>/dev/null)
    if [ "$RESULT" == "429" ]; then
        echo "  Request $i: HTTP 429 (RATE LIMITED)"
    else
        echo "  Request $i: HTTP $RESULT"
    fi
done

echo -e "\nIf you see HTTP 429, rate limiting is working!"
