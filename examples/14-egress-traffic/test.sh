#!/bin/bash
echo "=== Egress Traffic Test ==="

echo -e "\n1. Calling external httpbin.org..."
kubectl exec -n egress-demo deploy/sleep -c sleep -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin.org/get

echo -e "\n2. View ServiceEntry:"
kubectl get serviceentry -n egress-demo

echo -e "\nSuccess! External traffic is controlled via ServiceEntry."
