#!/bin/bash
# ============================================================================
# test.sh - Verify mTLS is active between services
# ============================================================================
# STEP 1: Test connectivity from sleep→httpbin (should work — both have sidecars)
# STEP 2: Check mTLS status using istioctl
#
# EXPECTED RESULTS:
#   In STRICT mode:
#     - sleep→httpbin: HTTP 200 (both have sidecars, mTLS works)
#     - Non-mesh pod→httpbin: Connection refused (no sidecar, no mTLS)
#   In PERMISSIVE mode:
#     - Both mesh and non-mesh pods can connect
# ============================================================================

echo "=== mTLS Test ==="

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Test from sleep (with sidecar) to httpbin
# ─────────────────────────────────────────────────────────────────────────────
# Both pods have Envoy sidecars, so mTLS is negotiated transparently.
# The sleep container sends plain HTTP; the sidecar encrypts it.
echo -e "\n1. Test connection from sleep to httpbin (should work with mTLS):"
kubectl exec -n mtls-demo deploy/sleep -c sleep -- \
  curl -s http://httpbin.mtls-demo/headers | head -5

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Verify mTLS status with istioctl
# ─────────────────────────────────────────────────────────────────────────────
# istioctl x describe shows the mTLS configuration and whether connections
# are encrypted. Look for "STRICT" or "mTLS" in the output.
echo -e "\n2. Check mTLS status:"
HTTPBIN_POD=$(kubectl get pod -n mtls-demo -l app=httpbin -o jsonpath='{.items[0].metadata.name}')
echo "   istioctl x describe pod $HTTPBIN_POD -n mtls-demo"
istioctl x describe pod "$HTTPBIN_POD" -n mtls-demo 2>/dev/null | grep -i "mtls" || echo "   Run: istioctl x describe pod $HTTPBIN_POD -n mtls-demo"
