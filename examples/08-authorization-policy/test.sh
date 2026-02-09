#!/bin/bash
echo "=== Authorization Policy Test ==="

echo -e "\n1. Before any policy (should work):"
kubectl exec -n authz-demo deploy/sleep -c sleep -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin/get

echo -e "\n2. Apply deny-all policy:"
kubectl apply -f authz-deny-all.yaml
sleep 2
kubectl exec -n authz-demo deploy/sleep -c sleep -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin/get
echo "   (Should be 403 Forbidden)"

echo -e "\n3. Apply allow-specific policy:"
kubectl apply -f authz-allow-specific.yaml
sleep 2
kubectl exec -n authz-demo deploy/sleep -c sleep -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin/get
echo "   (Should be 200 OK)"
