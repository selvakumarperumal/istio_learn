#!/bin/bash
echo "=== Load Balancing Test ==="

echo -e "\nSending 10 requests - check which pod handles each:"
for i in {1..10}; do
    POD=$(kubectl exec -n lb-demo deploy/httpbin -c httpbin -- \
      curl -s http://httpbin/headers 2>/dev/null | grep -o 'httpbin-[a-z0-9]*-[a-z0-9]*' | head -1)
    echo "  Request $i: $POD"
done

echo -e "\nWith Round Robin, you should see even distribution."
echo "With Consistent Hash + same x-user-id, same pod each time."
