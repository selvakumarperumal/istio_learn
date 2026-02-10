#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all load balancing demo resources
# ============================================================================
# Deletes the "lb-demo" namespace, removing all 3 httpbin replicas,
# Service, and whichever DestinationRule (LB algorithm) was active.
# ============================================================================

kubectl delete namespace lb-demo --ignore-not-found
echo "=== Cleanup Complete ==="
