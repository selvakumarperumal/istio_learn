#!/bin/bash
echo "=== mTLS Test ==="

echo -e "\n1. Test connection from sleep to httpbin (should work with mTLS):"
kubectl exec -n mtls-demo deploy/sleep -c sleep -- \
  curl -s http://httpbin.mtls-demo/headers | head -5

echo -e "\n2. Check mTLS status:"
HTTPBIN_POD=$(kubectl get pod -n mtls-demo -l app=httpbin -o jsonpath='{.items[0].metadata.name}')
echo "   istioctl x describe pod $HTTPBIN_POD -n mtls-demo"
istioctl x describe pod "$HTTPBIN_POD" -n mtls-demo 2>/dev/null | grep -i "mtls" || echo "   Run: istioctl x describe pod $HTTPBIN_POD -n mtls-demo"
