#!/bin/bash
echo "=== Note ==="
echo "Prometheus/Grafana are installed in istio-system namespace"
echo "To remove them:"
echo "  kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml"
echo "  kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml"
