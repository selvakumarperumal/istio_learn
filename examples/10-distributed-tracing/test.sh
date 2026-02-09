#!/bin/bash
echo "=== Generating Traces ==="

echo -e "\n1. Sending requests to generate traces..."
for i in {1..10}; do
    kubectl exec -n tracing-demo deploy/sleep -c sleep -- \
      curl -s http://httpbin.tracing-demo/headers > /dev/null
    echo "  Request $i sent"
done

echo -e "\n2. View traces in Jaeger:"
echo "   kubectl port-forward svc/tracing 16686:80 -n istio-system"
echo "   Open http://localhost:16686"
echo "   Select 'httpbin.tracing-demo' service"
