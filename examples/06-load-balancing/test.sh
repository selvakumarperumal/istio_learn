#!/bin/bash
# ============================================================================
# test.sh - Test load balancing distribution across replicas
# ============================================================================
# Sends 10 requests and shows which pod handled each one.
#
# EXPECTED RESULTS:
#   Round Robin:      Even distribution → Pod1, Pod2, Pod3, Pod1, Pod2...
#   Random:           Random distribution → Pod3, Pod1, Pod1, Pod2...
#   Least Connections: Adapts to load → goes to least-busy pod
#   Consistent Hash:  Same pod every time (if same x-user-id header)
#
# TIP: For consistent hash testing, add the header:
#   curl -H "x-user-id: user-123" http://httpbin/headers
# ============================================================================

echo "=== Load Balancing Test ==="

# Send 10 requests and extract the pod name from the response
echo -e "\nSending 10 requests - check which pod handles each:"
for i in {1..10}; do
    POD=$(kubectl exec -n lb-demo deploy/httpbin -c httpbin -- \
      curl -s http://httpbin/headers 2>/dev/null | grep -o 'httpbin-[a-z0-9]*-[a-z0-9]*' | head -1)
    echo "  Request $i: $POD"
done

echo -e "\nWith Round Robin, you should see even distribution."
echo "With Consistent Hash + same x-user-id, same pod each time."
