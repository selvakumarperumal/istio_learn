#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all egress traffic demo resources
# ============================================================================
# Deletes the "egress-demo" namespace, removing the sleep pod and
# the httpbin.org ServiceEntry.
# ============================================================================

kubectl delete namespace egress-demo --ignore-not-found
echo "=== Cleanup Complete ==="
