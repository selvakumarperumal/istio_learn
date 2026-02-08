#!/bin/bash
# deploy-all.sh - Deploy all resources in order

set -e

echo "=== Deploying Traffic Splitting Example ==="

echo -e "\n1. Creating namespace..."
kubectl apply -f namespace.yaml

echo -e "\n2. Deploying v1 (3 replicas)..."
kubectl apply -f deployment-v1.yaml

echo -e "\n3. Deploying v2 (1 replica)..."
kubectl apply -f deployment-v2.yaml

echo -e "\n4. Creating service..."
kubectl apply -f service.yaml

echo -e "\n5. Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n traffic-demo --timeout=120s

echo -e "\n6. Applying DestinationRule..."
kubectl apply -f destination-rule.yaml

echo -e "\n7. Applying VirtualService (80/20 split)..."
kubectl apply -f virtual-service.yaml

echo -e "\n8. Applying Gateway..."
kubectl apply -f gateway.yaml

echo -e "\n=== Deployment Complete ==="
echo -e "\nPods:"
kubectl get pods -n traffic-demo

echo -e "\nServices:"
kubectl get svc -n traffic-demo

echo -e "\nIstio resources:"
kubectl get virtualservice,destinationrule,gateway -n traffic-demo

echo -e "\n=== Testing Instructions ==="
echo "1. Get gateway URL: minikube service istio-ingressgateway -n istio-ingress --url"
echo "2. Test: curl -H 'Host: reviews.example.com' <URL>/version"
echo "3. Or run: ./test.sh"
