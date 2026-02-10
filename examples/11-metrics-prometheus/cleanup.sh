#!/bin/bash
# ============================================================================
# cleanup.sh - Remove Prometheus and Grafana from istio-system
# ============================================================================
# NOTE: These addons are installed in the istio-system namespace (shared).
# Only remove them if you no longer need metrics collection.
#
# This script prints instructions rather than auto-deleting to avoid
# accidentally removing shared monitoring infrastructure.
# ============================================================================

echo "=== Note ==="
echo "Prometheus/Grafana are installed in istio-system namespace"
echo "To remove them:"
echo "  kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml"
echo "  kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml"
