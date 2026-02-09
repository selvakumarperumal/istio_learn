#!/bin/bash
set -e
echo "=== Deploying Prometheus/Grafana ==="

echo -e "\n1. Installing Prometheus..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

echo -e "\n2. Installing Grafana..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml

echo -e "\n3. Waiting for pods..."
kubectl wait --for=condition=Ready pods -l app=prometheus -n istio-system --timeout=120s
kubectl wait --for=condition=Ready pods -l app=grafana -n istio-system --timeout=120s

echo -e "\n=== Deployment Complete ==="
echo "Access Prometheus: kubectl port-forward svc/prometheus 9090:9090 -n istio-system"
echo "Access Grafana:    kubectl port-forward svc/grafana 3000:3000 -n istio-system"
echo "                   Open http://localhost:3000 (admin/admin)"
