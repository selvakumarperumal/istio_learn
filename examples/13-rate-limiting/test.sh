#!/bin/bash
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
