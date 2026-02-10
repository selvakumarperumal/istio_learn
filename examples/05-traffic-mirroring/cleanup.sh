#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all traffic mirroring demo resources
# ============================================================================
# Deletes the "mirror-demo" namespace, removing:
#   - httpbin-v1 and httpbin-v2 Deployments and pods
#   - httpbin Service
#   - DestinationRule (v1/v2 subset definitions)
#   - VirtualService (mirroring configuration)
# ============================================================================

kubectl delete namespace mirror-demo --ignore-not-found
echo "=== Cleanup Complete ==="
