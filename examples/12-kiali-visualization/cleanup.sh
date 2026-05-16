#!/bin/bash
# ============================================================================
# cleanup.sh - Remove Kiali from istio-system
# ============================================================================
# NOTE: Kiali is installed in the istio-system namespace (shared).
# Only remove if you no longer need service mesh visualization.
#
# This script prints instructions rather than auto-deleting to avoid
# accidentally removing shared infrastructure.
# ============================================================================

echo "=== Note ==="
echo "Kiali is installed in istio-system namespace"
echo "To remove: kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/kiali.yaml"
