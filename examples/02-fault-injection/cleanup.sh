#!/bin/bash
# ============================================================================
# cleanup.sh - Remove all fault injection demo resources
# ============================================================================
# WHAT THIS SCRIPT DOES:
#   Deletes the entire "fault-demo" namespace, which automatically removes:
#     - httpbin Deployment and its pods
#     - httpbin Service
#     - Gateway API Gateway and HTTPRoute resources
#     - All VirtualService resources (fault-delay, fault-abort, fault-combined)
#     - Any ConfigMaps, Secrets, or other resources in the namespace
#
# WHY DELETE THE NAMESPACE?
#   Deleting the namespace is the cleanest way to tear down a demo.
#   It removes ALL resources in one operation, ensuring nothing is left behind.
#   The --ignore-not-found flag prevents errors if the namespace doesn't exist.
#
#   The Gateway API provisions a gateway Service in the namespace, which
#   is automatically cleaned up when the namespace is deleted.
#
# USAGE:
#   ./cleanup.sh
# ============================================================================

echo "=== Cleaning Up Fault Injection Example ==="
kubectl delete namespace fault-demo --ignore-not-found
echo "=== Cleanup Complete ==="
