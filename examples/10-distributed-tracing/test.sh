#!/bin/bash
# ============================================================================
# test.sh - Generate traces for visualization in Jaeger
# ============================================================================
# Sends 10 requests from sleep→httpbin to create trace data.
# Each request generates spans that can be viewed in Jaeger.
#
# AFTER RUNNING:
#   1. Open Jaeger: kubectl port-forward svc/tracing 16686:80 -n istio-system
#   2. Go to http://localhost:16686
#   3. Select "httpbin.tracing-demo" from the service dropdown
#   4. Click "Find Traces" to see the request flow
#
# WHAT YOU'LL SEE:
#   Each trace shows the full request path:
#     Client → Envoy (sleep sidecar) → Envoy (httpbin sidecar) → httpbin
#   With timing for each hop.
# ============================================================================

echo "=== Generating Traces ==="

# Send 10 requests to generate a representative set of traces
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
