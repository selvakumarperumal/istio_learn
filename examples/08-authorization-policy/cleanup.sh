#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all authorization policy demo resources
# ============================================================================
# Deletes the "authz-demo" namespace, removing:
#   - httpbin and sleep Deployments, Services, and ServiceAccounts
#   - AuthorizationPolicy resources (deny-all, allow-specific)
# ============================================================================

kubectl delete namespace authz-demo --ignore-not-found
echo "=== Cleanup Complete ==="
