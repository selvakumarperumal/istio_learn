#!/bin/bash
echo "=== Traffic Mirroring Test ==="

echo -e "\n1. Sending requests to v1..."
kubectl exec -n mirror-demo deploy/httpbin-v1 -c httpbin -- \
  curl -s http://httpbin/headers | head -5

echo -e "\n2. Check v2 logs for mirrored requests:"
echo "   kubectl logs -n mirror-demo deploy/httpbin-v2 -c httpbin -f"
echo ""
echo "   You should see incoming requests even though we only called v1!"
