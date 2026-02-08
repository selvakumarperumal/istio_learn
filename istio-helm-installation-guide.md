# Istio Installation Guide with Helm

> **Reference**: This guide is based on the [Official Istio Helm Installation Documentation](https://istio.io/latest/docs/setup/install/helm/)

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Steps](#installation-steps)
3. [Verification](#verification)
4. [Enabling Sidecar Injection](#enabling-sidecar-injection)
5. [Troubleshooting](#troubleshooting)
6. [Uninstallation](#uninstallation)
7. [Configuration Options](#configuration-options)

---

## Prerequisites

Before installing Istio, ensure you have:

### 1. Kubernetes Cluster

```bash
# Verify your cluster is running
kubectl cluster-info

# Check Kubernetes version (Istio 1.28 supports K8s 1.28-1.32)
kubectl version --short
```

### 2. Helm 3.x Installed

```bash
# Check Helm version
helm version

# If not installed, install Helm:
# curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 3. Add Istio Helm Repository

```bash
# Add the official Istio Helm repository
helm repo add istio https://istio-release.storage.googleapis.com/charts

# Update repository cache
helm repo update

# Verify available charts
helm search repo istio
```

**Expected output:**
```
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
istio/base              1.28.3          1.28.3          Helm chart for deploying Istio cluster resources...
istio/istiod            1.28.3          1.28.3          Helm chart for istio control plane
istio/gateway           1.28.3          1.28.3          Helm chart for deploying Istio gateways
istio/cni               1.28.3          1.28.3          Helm chart for istio-cni components
istio/ztunnel           1.28.3          1.28.3          Helm chart for istio ztunnel components
```

---

## Installation Steps

### Architecture Overview

Istio installation consists of three main components:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Istio Components                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   1. istio-base (CRDs)                                                  │
│      └── Custom Resource Definitions (VirtualService, Gateway, etc.)   │
│      └── Installed in: istio-system namespace                          │
│                                                                         │
│   2. istiod (Control Plane)                                             │
│      └── Pilot (traffic management)                                    │
│      └── Citadel (security/mTLS)                                       │
│      └── Galley (configuration)                                        │
│      └── Installed in: istio-system namespace                          │
│                                                                         │
│   3. istio-gateway (Data Plane - Optional)                              │
│      └── Ingress Gateway (external traffic)                            │
│      └── Egress Gateway (outgoing traffic - optional)                  │
│      └── Installed in: istio-ingress namespace (recommended)           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### Step 1: Create the istio-system Namespace

```bash
kubectl create namespace istio-system
```

---

### Step 2: Install Istio Base (CRDs)

The base chart installs Custom Resource Definitions (CRDs) required by Istio.

```bash
helm install istio-base istio/base \
  -n istio-system \
  --set defaultRevision=default \
  --wait
```

**Verify installation:**
```bash
helm ls -n istio-system

# Expected output:
# NAME        NAMESPACE     REVISION  STATUS    CHART         APP VERSION
# istio-base  istio-system  1         deployed  base-1.28.3   1.28.3
```

**Check CRDs are installed:**
```bash
kubectl get crd | grep istio

# Expected: You should see CRDs like:
# destinationrules.networking.istio.io
# gateways.networking.istio.io
# virtualservices.networking.istio.io
# ...
```

---

### Step 3: Install Istiod (Control Plane)

Istiod is the control plane that manages the service mesh.

```bash
helm install istiod istio/istiod \
  -n istio-system \
  --wait
```

**Verify installation:**
```bash
# Check Helm release
helm ls -n istio-system

# Check istiod pod is running
kubectl get pods -n istio-system

# Expected output:
# NAME                      READY   STATUS    RESTARTS   AGE
# istiod-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

**Get detailed status:**
```bash
helm status istiod -n istio-system
```

---

### Step 4: Install Istio Ingress Gateway (Optional but Recommended)

The gateway allows external traffic to enter your mesh.

```bash
# Create dedicated namespace for ingress
kubectl create namespace istio-ingress

# Label namespace for sidecar injection (recommended)
kubectl label namespace istio-ingress istio-injection=enabled

# Install the gateway
helm install istio-ingressgateway istio/gateway \
  -n istio-ingress \
  --wait
```

**Verify installation:**
```bash
# Check gateway pod
kubectl get pods -n istio-ingress

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# istio-ingressgateway-xxxxxxxxxx-xxxxx   1/1     Running   0          1m

# Check gateway service
kubectl get svc -n istio-ingress

# Expected output:
# NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)
# istio-ingressgateway   LoadBalancer   10.x.x.x        <pending>     15021:xxxxx/TCP,80:xxxxx/TCP,443:xxxxx/TCP
```

> **Note for Minikube**: The EXTERNAL-IP will show `<pending>`. Run `minikube tunnel` in a separate terminal to get an IP.

---

## Verification

### Verify All Components

```bash
echo "=== Helm Releases ==="
helm ls -n istio-system
helm ls -n istio-ingress

echo "=== Istio Pods ==="
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress

echo "=== Istio Services ==="
kubectl get svc -n istio-system
kubectl get svc -n istio-ingress

echo "=== Istio CRDs ==="
kubectl get crd | grep istio | wc -l
echo "Istio CRDs installed"
```

### Expected Final State

| Component | Namespace | Pods | Status |
|-----------|-----------|------|--------|
| istio-base | istio-system | (CRDs only) | deployed |
| istiod | istio-system | 1/1 Running | deployed |
| istio-ingressgateway | istio-ingress | 1/1 Running | deployed |

---

## Enabling Sidecar Injection

For Istio to work, your application pods need the Envoy sidecar proxy injected.

### Method 1: Namespace Label (Recommended)

```bash
# Enable automatic injection for a namespace
kubectl label namespace <your-namespace> istio-injection=enabled

# Verify
kubectl get namespace -L istio-injection
```

### Method 2: Pod Annotation

Add this annotation to your pod spec:
```yaml
metadata:
  annotations:
    sidecar.istio.io/inject: "true"
```

### Verify Injection is Working

```bash
# Deploy a test pod
kubectl run test-pod --image=nginx -n <your-namespace>

# Check if sidecar was injected (should show 2/2 containers)
kubectl get pods -n <your-namespace>

# Expected: 2/2 READY means sidecar was injected
# NAME       READY   STATUS    RESTARTS   AGE
# test-pod   2/2     Running   0          30s
```

---

## Troubleshooting

### Issue: Istiod Not Starting

```bash
# Check pod status
kubectl describe pod -n istio-system -l app=istiod

# Check logs
kubectl logs -n istio-system -l app=istiod

# Common causes:
# - CRD version mismatch (upgrade istio-base first)
# - Insufficient resources (check node capacity)
# - Network policies blocking communication
```

### Issue: Sidecar Not Injecting

```bash
# Verify namespace label
kubectl get namespace <namespace> -o yaml | grep istio-injection

# Check MutatingWebhookConfiguration
kubectl get mutatingwebhookconfiguration | grep istio

# Restart deployment to trigger injection
kubectl rollout restart deployment <deployment-name> -n <namespace>
```

### Issue: CRD Version Mismatch

If you see errors about missing CRDs or API versions:

```bash
# Upgrade istio-base to match istiod version
helm upgrade istio-base istio/base -n istio-system

# If upgrade fails due to ownership issues, clean and reinstall:
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system
kubectl get crd | grep istio | awk '{print $1}' | xargs kubectl delete crd
# Then reinstall from Step 2
```

### Issue: Gateway External-IP Pending (Minikube)

```bash
# Run in a separate terminal
minikube tunnel

# Or use NodePort access
minikube service istio-ingressgateway -n istio-ingress --url
```

---

## Uninstallation

### Step 1: Uninstall Gateway (if installed)

```bash
helm uninstall istio-ingressgateway -n istio-ingress
kubectl delete namespace istio-ingress
```

### Step 2: Uninstall Istiod

```bash
helm uninstall istiod -n istio-system
```

### Step 3: Uninstall Istio Base

```bash
helm uninstall istio-base -n istio-system
```

### Step 4: Delete CRDs (Optional)

> ⚠️ **Warning**: This will delete all Istio resources (VirtualServices, Gateways, etc.)

```bash
kubectl get crd | grep istio | awk '{print $1}' | xargs kubectl delete crd
```

### Step 5: Delete Namespace

```bash
kubectl delete namespace istio-system
```

---

## Configuration Options

### View Available Configuration

```bash
# Show all configurable values for istiod
helm show values istio/istiod

# Show all configurable values for gateway
helm show values istio/gateway
```

### Common Customizations

#### Custom Resource Limits for Istiod

```bash
helm install istiod istio/istiod -n istio-system \
  --set pilot.resources.requests.cpu=500m \
  --set pilot.resources.requests.memory=512Mi \
  --set pilot.resources.limits.cpu=1000m \
  --set pilot.resources.limits.memory=1Gi \
  --wait
```

#### Custom Gateway Service Type

```bash
# Use NodePort instead of LoadBalancer (useful for on-prem)
helm install istio-ingressgateway istio/gateway -n istio-ingress \
  --set service.type=NodePort \
  --wait
```

#### Using Values File

Create a `values.yaml`:
```yaml
# istiod-values.yaml
pilot:
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  autoscaleEnabled: true
  autoscaleMin: 1
  autoscaleMax: 5

global:
  proxy:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
```

Install with values file:
```bash
helm install istiod istio/istiod -n istio-system -f istiod-values.yaml --wait
```

---

## Quick Reference

### One-Line Installation

```bash
# Complete installation in one go
kubectl create namespace istio-system && \
helm install istio-base istio/base -n istio-system --set defaultRevision=default --wait && \
helm install istiod istio/istiod -n istio-system --wait && \
kubectl create namespace istio-ingress && \
kubectl label namespace istio-ingress istio-injection=enabled && \
helm install istio-ingressgateway istio/gateway -n istio-ingress --wait
```

### One-Line Uninstallation

```bash
# Complete uninstallation
helm uninstall istio-ingressgateway -n istio-ingress 2>/dev/null; \
helm uninstall istiod -n istio-system 2>/dev/null; \
helm uninstall istio-base -n istio-system 2>/dev/null; \
kubectl delete namespace istio-ingress istio-system 2>/dev/null; \
kubectl get crd | grep istio | awk '{print $1}' | xargs kubectl delete crd 2>/dev/null
```

---

## Official References

- [Istio Helm Installation Guide](https://istio.io/latest/docs/setup/install/helm/)
- [Gateway Installation](https://istio.io/latest/docs/setup/additional-setup/gateway/)
- [Sidecar Injection](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/)
- [Istio Configuration Reference](https://istio.io/latest/docs/reference/config/)
- [Helm Chart Values (ArtifactHub)](https://artifacthub.io/packages/helm/istio-official/istiod)
- [Supported Kubernetes Versions](https://istio.io/latest/docs/releases/supported-releases/)
