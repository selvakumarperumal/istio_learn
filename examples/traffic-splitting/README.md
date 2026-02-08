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
              │ app: myapp   │          │ app: myapp   │
              │ version: v1  │          │ version: v2  │
              └──────────────┘          └──────────────┘
```

## 📍 NAMING CLARIFICATION

We use **DIFFERENT names** to clearly show what matches what:

| What | Name | Where Defined |
|------|------|---------------|
| **Service NAME** | `reviews-svc` | service.yaml `metadata.name` |
| **App LABEL** | `myapp` | deployment pods `labels.app` |
| **Version LABEL** | `v1` / `v2` | deployment pods `labels.version` |
| **DestinationRule HOST** | `reviews-svc` | destination-rule.yaml `host` |

**How matching works:**
```
DestinationRule host: reviews-svc  →  matches Service NAME (not app label!)
Service selector: app: myapp       →  matches Pod LABEL
DestinationRule subset: version: v1 → further filters pods
```

## 📁 Files Included

| File | Description |
|------|-------------|
| `namespace.yaml` | Creates namespace with Istio injection |
| `deployment-v1.yaml` | Deployment for version 1 (3 replicas, app=myapp) |
| `deployment-v2.yaml` | Deployment for version 2 (1 replica, app=myapp) |
| `service.yaml` | Kubernetes Service **named reviews-svc** |
| `destination-rule.yaml` | Defines v1 and v2 subsets (host: reviews-svc) |
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

### Step 2: Deploy Version 1 (3 replicas)

```bash
kubectl apply -f deployment-v1.yaml
```

### Step 3: Deploy Version 2 (1 replica)

```bash
kubectl apply -f deployment-v2.yaml
```

### Step 4: Create the Service

```bash
kubectl apply -f service.yaml
```

### Step 5: Wait for pods to be ready

```bash
kubectl wait --for=condition=Ready pods --all -n traffic-demo --timeout=120s
```

### Step 6: Apply DestinationRule

```bash
kubectl apply -f destination-rule.yaml
```

### Step 7: Apply VirtualService

```bash
kubectl apply -f virtual-service.yaml
```

### Step 8: Apply Gateway

```bash
kubectl apply -f gateway.yaml
```

## 🧪 Testing the Traffic Split

### Quick Deploy All

```bash
./deploy-all.sh
```

### Test Traffic Distribution

```bash
./test.sh
```

### Get the Gateway URL (Minikube)

```bash
# In a separate terminal
minikube tunnel

# Get the external IP
export INGRESS_IP=$(kubectl get svc -n istio-ingress istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Send test requests
for i in {1..10}; do
  curl -s -H "Host: reviews.example.com" http://$INGRESS_IP/version
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

## 🧹 Cleanup

```bash
./cleanup.sh
# or
kubectl delete namespace traffic-demo
```

## 🔍 Key Concepts Summary

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   Request → Gateway → VirtualService → DestinationRule → Pods          │
│                                                                         │
│   ┌────────────────────────────────────────────────────────────────────┐│
│   │  VirtualService (host: reviews-svc)                               ││
│   │  └── Routes traffic to Service by NAME                            ││
│   │                                                                    ││
│   │  DestinationRule (host: reviews-svc)                              ││
│   │  └── Defines subsets by pod LABELS (version: v1, v2)             ││
│   │                                                                    ││
│   │  Service (name: reviews-svc, selector: app=myapp)                 ││
│   │  └── Finds pods by LABEL (app=myapp)                              ││
│   │                                                                    ││
│   │  Pods (labels: app=myapp, version=v1 or v2)                       ││
│   │  └── Have BOTH labels for matching                                ││
│   └────────────────────────────────────────────────────────────────────┘│
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```
