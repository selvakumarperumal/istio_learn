#!/bin/bash
# ============================================================================
# deploy-all.sh - Deploy Prometheus and Grafana for Istio Metrics
# ============================================================================
# Installs the Istio addon versions of Prometheus and Grafana into the
# istio-system namespace. These are pre-configured to scrape Envoy metrics.
#
# WHAT GETS DEPLOYED:
#   - Prometheus: Collects metrics from all Envoy sidecars in the mesh
#   - Grafana: Pre-built dashboards for Istio service mesh monitoring
#
# KEY METRICS COLLECTED:
#   - istio_requests_total: Total request count by source, destination, status
#   - istio_request_duration_milliseconds: Request latency histograms
#   - istio_tcp_sent_bytes_total: TCP traffic volume
#   - envoy_server_memory_allocated: Envoy memory usage
#
# AFTER DEPLOYMENT:
#   Prometheus: kubectl port-forward svc/prometheus 9090:9090 -n istio-system
#               Open http://localhost:9090
#   Grafana:    kubectl port-forward svc/grafana 3000:3000 -n istio-system
#               Open http://localhost:3000 (default: admin/admin)
#
# GRAFANA DASHBOARDS:
#   - Istio Mesh Dashboard: Overall mesh health
#   - Istio Service Dashboard: Per-service metrics
#   - Istio Workload Dashboard: Per-pod/workload metrics
# ============================================================================

set -e
echo "=== Deploying Prometheus/Grafana ==="

# Step 1: Install Prometheus (metrics collection)
echo -e "\n1. Installing Prometheus..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/prometheus.yaml

# Step 2: Install Grafana (metrics visualization with pre-built dashboards)
echo -e "\n2. Installing Grafana..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/grafana.yaml

# Step 3: Wait for pods to be Ready
echo -e "\n3. Waiting for pods..."
kubectl wait --for=condition=Ready pods -l app=prometheus -n istio-system --timeout=120s
kubectl wait --for=condition=Ready pods -l app=grafana -n istio-system --timeout=120s

echo -e "\n=== Deployment Complete ==="
echo "Access Prometheus: kubectl port-forward svc/prometheus 9090:9090 -n istio-system"
echo "Access Grafana:    kubectl port-forward svc/grafana 3000:3000 -n istio-system"
echo "                   Open http://localhost:3000 (admin/admin)"
