#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all JWT authentication demo resources
# ============================================================================
# Deletes the "jwt-demo" namespace, removing httpbin, Gateway,
# VirtualService, RequestAuthentication, and AuthorizationPolicy.
# ============================================================================

kubectl delete namespace jwt-demo --ignore-not-found
echo "=== Cleanup Complete ==="
