# Traffic Splitting Example (80/20 Canary Deployment)

This example demonstrates how to split traffic between two versions of a service using Istio VirtualService.

## 📋 What You'll Learn

- Deploy two versions of the same application (v1 and v2)
- Configure Istio to split traffic (80% → v1, 20% → v2)
- Test and verify the traffic splitting

## 🏗️ Architecture

```
                     ┌─────────────────────────────────────────┐
                     │          Traffic Splitting              │
                     └─────────────────────────────────────────┘

                              Incoming Request
                                     │
                                     ▼
                           ┌─────────────────┐
                           │ VirtualService  │
                           │ (Traffic Rules) │
                           └────────┬────────┘
                                    │
                       ┌────────────┴────────────┐
                       │                         │
                    80% ▼                     20% ▼
              ┌──────────────┐          ┌──────────────┐
              │  reviews-v1  │          │  reviews-v2  │
              │  (3 pods)    │          │  (1 pod)     │
              │              │          │              │
              │ Returns:     │          │ Returns:     │
              │ "Version 1"  │          │ "Version 2"  │
              └──────────────┘          └──────────────┘
```

## 📁 Files Included

| File | Description |
|------|-------------|
| `namespace.yaml` | Creates namespace with Istio injection |
| `deployment-v1.yaml` | Deployment for version 1 (3 replicas) |
| `deployment-v2.yaml` | Deployment for version 2 (1 replica) |
| `service.yaml` | Kubernetes Service for reviews |
| `destination-rule.yaml` | Defines v1 and v2 subsets |
| `virtual-service.yaml` | Traffic splitting rules (80/20) |
| `gateway.yaml` | Exposes service externally |

## 🚀 Prerequisites

Before running this example, ensure Istio is installed:

```bash
# Check Istio installation
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress

# Expected: istiod and gateway pods should be Running
```

## 📝 Step-by-Step Instructions

### Step 1: Create Namespace with Sidecar Injection

```bash
kubectl apply -f namespace.yaml
```

**Verify:**
```bash
kubectl get namespace traffic-demo --show-labels
# Should show: istio-injection=enabled
```

### Step 2: Deploy Version 1 (3 replicas)

```bash
kubectl apply -f deployment-v1.yaml
```

**Verify:**
```bash
kubectl get pods -n traffic-demo -l version=v1
# Wait for all pods to show 2/2 Running (app + sidecar)
```

### Step 3: Deploy Version 2 (1 replica)

```bash
kubectl apply -f deployment-v2.yaml
```

**Verify:**
```bash
kubectl get pods -n traffic-demo -l version=v2
# Should show 1 pod with 2/2 Running
```

### Step 4: Create the Service

```bash
kubectl apply -f service.yaml
```

**Verify:**
```bash
kubectl get svc -n traffic-demo
# reviews ClusterIP should be created
```

### Step 5: Apply DestinationRule (Define Subsets)

```bash
kubectl apply -f destination-rule.yaml
```

**Verify:**
```bash
kubectl get destinationrule -n traffic-demo
# reviews destination rule should exist
```

### Step 6: Apply VirtualService (Traffic Splitting)

```bash
kubectl apply -f virtual-service.yaml
```

**Verify:**
```bash
kubectl get virtualservice -n traffic-demo
# reviews virtual service should exist
```

### Step 7: Apply Gateway (External Access)

```bash
kubectl apply -f gateway.yaml
```

**Verify:**
```bash
kubectl get gateway -n traffic-demo
# reviews-gateway should exist
```

## 🧪 Testing the Traffic Split

### Get the Gateway URL

```bash
# For Minikube - run this in a separate terminal
minikube tunnel

# Get the external IP
export INGRESS_IP=$(kubectl get svc -n istio-ingress istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Gateway IP: $INGRESS_IP"

# Or use minikube service
minikube service istio-ingressgateway -n istio-ingress --url
```

### Send Test Requests

```bash
# Send 10 requests and see the distribution
for i in {1..10}; do
  curl -s -H "Host: reviews.example.com" http://$INGRESS_IP/version
  echo
done
```

**Expected Output (approximately):**
```
Version: v1
Version: v1
Version: v1
Version: v1
Version: v1
Version: v1
Version: v1
Version: v1
Version: v2
Version: v2
```

### Statistical Test (100 requests)

```bash
# Count distribution over 100 requests
echo "Sending 100 requests..."
for i in {1..100}; do
  curl -s -H "Host: reviews.example.com" http://$INGRESS_IP/version
done | sort | uniq -c | sort -rn

# Expected output (approximately):
#   80 Version: v1
#   20 Version: v2
```

## 🔄 Modify Traffic Split

### Change to 50/50 Split

Edit `virtual-service.yaml`:
```yaml
weight: 50  # for v1
weight: 50  # for v2
```

Apply:
```bash
kubectl apply -f virtual-service.yaml
```

### Route All Traffic to v2 (Complete Migration)

```yaml
- destination:
    host: reviews
    subset: v2
  weight: 100
```

### Route Specific Users to v2

```yaml
http:
  # Users with header "x-user: beta" go to v2
  - match:
      - headers:
          x-user:
            exact: beta
    route:
      - destination:
          host: reviews
          subset: v2
  # Everyone else goes to v1
  - route:
      - destination:
          host: reviews
          subset: v1
```

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete namespace traffic-demo

# Verify
kubectl get all -n traffic-demo
# Should show: No resources found
```

## 🔍 Troubleshooting

### Pods Not Getting Sidecars (1/1 instead of 2/2)

```bash
# Check namespace label
kubectl get namespace traffic-demo --show-labels

# Re-label if needed
kubectl label namespace traffic-demo istio-injection=enabled --overwrite

# Restart pods
kubectl rollout restart deployment -n traffic-demo
```

### VirtualService Not Working

```bash
# Check if VirtualService is applied correctly
kubectl describe virtualservice reviews -n traffic-demo

# Check istiod logs for errors
kubectl logs -n istio-system -l app=istiod | grep -i error
```

### Can't Access via Gateway

```bash
# Check gateway pod is running
kubectl get pods -n istio-ingress

# Check gateway service has external IP
kubectl get svc -n istio-ingress istio-ingressgateway

# Check gateway resource
kubectl describe gateway reviews-gateway -n traffic-demo
```

## 📚 Key Concepts

### VirtualService
Defines **how** traffic is routed to services. Used for:
- Traffic splitting (weights)
- Header-based routing
- URL rewriting
- Timeouts and retries

### DestinationRule
Defines **what happens** after routing. Used for:
- Subsets (versions)
- Load balancing policies
- Connection pool settings
- TLS settings

### Gateway
Defines **entry points** for external traffic. Used for:
- Host matching
- Port configuration
- TLS termination

```
Request → Gateway → VirtualService → DestinationRule → Service → Pod
           (entry)    (routing)        (policy)
```
