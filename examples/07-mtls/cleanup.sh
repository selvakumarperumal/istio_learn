#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all mTLS demo resources
# ============================================================================
# Deletes the "mtls-demo" namespace, removing httpbin, sleep,
# PeerAuthentication policies, and all associated resources.
# ============================================================================

kubectl delete namespace mtls-demo --ignore-not-found
echo "=== Cleanup Complete ==="
