#!/bin/bash
echo "=== Circuit Breaker Test ==="

FORTIO_POD=$(kubectl get pods -n circuit-demo -l app=fortio -o jsonpath='{.items[0].metadata.name}')

echo -e "\n1. Single request (should work):"
kubectl exec -n circuit-demo "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio curl http://httpbin:80/get

echo -e "\n2. Concurrent requests (should trigger circuit breaker):"
echo "   Sending 20 requests with 3 concurrent connections..."
kubectl exec -n circuit-demo "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio load -c 3 -qps 0 -n 20 -loglevel Warning http://httpbin:80/get

echo -e "\n=== Results ==="
echo "If you see 'upstream_rq_pending_overflow' or HTTP 503 errors,"
echo "the circuit breaker is working!"
