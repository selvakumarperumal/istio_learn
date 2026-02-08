# Building Custom Istio Helm Charts from Scratch
## Complete Guide with Kubernetes vs Helm Comparison

---

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Why Build Custom Charts](#why-build-custom-charts)
3. [Project Structure](#project-structure)
4. [Building Each Component](#building-each-component)
5. [Complete Working Example](#complete-working-example)
6. [Installation & Testing](#installation--testing)
7. [Advanced Patterns](#advanced-patterns)

---

## Architecture Overview

### Istio Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Istio Architecture                        │
└─────────────────────────────────────────────────────────────┘

                    Control Plane
    ┌──────────────────────────────────────────┐
    │         Istiod (Pilot+Citadel)           │
    │  ┌────────────────────────────────────┐  │
    │  │ - Service Discovery                │  │
    │  │ - Configuration Management         │  │
    │  │ - Certificate Authority            │  │
    │  └────────────────────────────────────┘  │
    └───────────────────┬──────────────────────┘
                        │ Config Push
        ┌───────────────┼───────────────┐
        │               │               │
    ┌───▼───┐       ┌───▼───┐      ┌───▼───┐
    │Gateway│       │ App-A │      │ App-B │
    │┌─────┐│       │┌─────┐│      │┌─────┐│
    ││Envoy││       ││ App ││      ││ App ││
    │└─────┘│       │└─────┘│      │└─────┘│
    │       │       │┌─────┐│      │┌─────┐│
    │       │       ││Envoy││      ││Envoy││
    │       │       │└─────┘│      │└─────┘│
    └───────┘       └───────┘      └───────┘
   Ingress/         Data Plane     Data Plane
    Egress
```

### Helm Chart Dependency Flow

```
┌──────────────────────────────────────────────────────────┐
│              Helm Chart Dependencies                      │
└──────────────────────────────────────────────────────────┘

    Application Chart
         │
         ├─► istio-base (CRDs)
         │
         ├─► istiod (Control Plane)
         │
         └─► istio-gateway (Ingress)


Installation Order:
  1. istio-base    → CRDs
  2. istiod        → Control Plane  
  3. istio-gateway → Gateways
  4. application   → Your Apps
```

---

## Why Build Custom Charts?

### Benefits

1. **Full Control**: Customize every aspect for your needs
2. **Learning**: Deep understanding of Istio internals
3. **GitOps**: Version control for infrastructure
4. **Flexibility**: Add custom resources and configurations
5. **Reusability**: Create organization-specific standards

### Comparison: Official vs Custom

| Aspect | Official Charts | Custom Charts |
|--------|----------------|---------------|
| Setup Time | Minutes | Hours (initial) |
| Customization | Limited | Complete |
| Learning Curve | Low | High |
| Maintenance | Istio Team | Your Team |
| Upgrades | Easy | Manual |
| Best For | Quick starts | Production, Learning |

---

## Project Structure

```
istio-charts/
│
├── istio-base/           # CRD Chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── namespace.yaml
│   │   └── crds/
│   │       ├── virtualservice.yaml
│   │       ├── destinationrule.yaml
│   │       ├── gateway.yaml
│   │       └── ...
│   └── README.md
│
├── istiod/               # Control Plane Chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── serviceaccount.yaml
│   │   ├── clusterrole.yaml
│   │   ├── clusterrolebinding.yaml
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── hpa.yaml
│   │   └── pdb.yaml
│   └── README.md
│
├── istio-gateway/        # Gateway Chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── serviceaccount.yaml
│   │   ├── role.yaml
│   │   ├── rolebinding.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   └── README.md
│
└── bookstore-app/        # Example Application
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    │   ├── _helpers.tpl
    │   ├── namespace.yaml
    │   ├── deployments/
    │   ├── services/
    │   ├── gateway.yaml
    │   ├── virtualservice.yaml
    │   ├── destinationrule.yaml
    │   └── peerauthentication.yaml
    └── README.md
```

---

## Building Each Component

## 1. Istio Base Chart (CRDs)

### Chart.yaml
```yaml
apiVersion: v2
name: istio-base
description: Istio Custom Resource Definitions
type: application
version: 1.0.0
appVersion: "1.21.0"
```

### values.yaml
```yaml
global:
  istioNamespace: istio-system

defaultRevision: "default"

base:
  enableIstioConfigCRDs: true
  validation:
    enabled: true
```

### Kubernetes Manifest vs Helm Template

#### **Kubernetes Manifest** (Pure YAML)

```yaml
# kubernetes/virtualservice-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: virtualservices.networking.istio.io
  labels:
    app: istio-base
    release: manual-install
spec:
  group: networking.istio.io
  names:
    kind: VirtualService
    plural: virtualservices
    singular: virtualservice
    shortNames: [vs]
  scope: Namespaced
  versions:
  - name: v1beta1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              hosts:
                type: array
                items:
                  type: string
```

**To apply:**
```bash
kubectl apply -f kubernetes/virtualservice-crd.yaml
```

#### **Helm Template** (Templated YAML)

```yaml
# istio-base/templates/crds/virtualservice.yaml
{{- if .Values.base.enableIstioConfigCRDs }}
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: virtualservices.networking.istio.io
  labels:
    {{- include "istio-base.labels" . | nindent 4 }}
  annotations:
    "helm.sh/resource-policy": keep
spec:
  group: networking.istio.io
  names:
    kind: VirtualService
    plural: virtualservices
    singular: virtualservice
    shortNames: [vs]
  scope: Namespaced
  versions:
  - name: v1beta1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            # Full schema omitted for brevity
{{- end }}
```

**To install:**
```bash
helm install istio-base ./istio-base -n istio-system --create-namespace
```

### Key Differences

| Aspect | Kubernetes | Helm |
|--------|-----------|------|
| Templating | No | Yes ({{  }}) |
| Reusability | Copy/paste | Chart package |
| Conditionals | No | Yes ({{- if }}) |
| Values | Hardcoded | External values.yaml |
| Rollback | Manual | `helm rollback` |
| Upgrades | kubectl apply | `helm upgrade` |

### _helpers.tpl (Helm Template Functions)

```yaml
# istio-base/templates/_helpers.tpl

{{/*
Chart name
*/}}
{{- define "istio-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "istio-base.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "istio-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Istio namespace
*/}}
{{- define "istio-base.namespace" -}}
{{- default "istio-system" .Values.global.istioNamespace }}
{{- end }}
```

---

## 2. Istiod Chart (Control Plane)

### Chart.yaml
```yaml
apiVersion: v2
name: istiod
description: Istio Control Plane
type: application
version: 1.0.0
appVersion: "1.21.0"
dependencies:
  - name: istio-base
    version: "1.0.0"
    repository: "file://../istio-base"
```

### values.yaml
```yaml
global:
  istioNamespace: istio-system
  proxy:
    image: istio/proxyv2:1.21.0
    resources:
      requests:
        cpu: 100m
        memory: 128Mi

pilot:
  enabled: true
  replicaCount: 2
  image:
    repository: istio/pilot
    tag: 1.21.0
  resources:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      cpu: 4000m
      memory: 8Gi
  autoscaleEnabled: true
  autoscaleMin: 2
  autoscaleMax: 5

meshConfig:
  accessLogFile: /dev/stdout
  outboundTrafficPolicy:
    mode: ALLOW_ANY
```

### Side-by-Side Comparison: Deployment

#### **Kubernetes Manifest**

```yaml
# kubernetes/istiod-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
  labels:
    app: istiod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: istiod
  template:
    metadata:
      labels:
        app: istiod
    spec:
      serviceAccountName: istiod
      containers:
      - name: discovery
        image: istio/pilot:1.21.0
        ports:
        - containerPort: 15010
        - containerPort: 15017
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
```

**Issues with pure Kubernetes:**
- ❌ Hardcoded values (replicas, image tags)
- ❌ No easy way to change for different environments
- ❌ Duplicate configs for dev/staging/prod
- ❌ Manual version management

#### **Helm Template**

```yaml
# istiod/templates/deployment.yaml
{{- if .Values.pilot.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.pilot.replicaCount }}
  selector:
    matchLabels:
      {{- include "istiod.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "istiod.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ .Values.serviceAccount.name }}
      containers:
      - name: discovery
        image: "{{ .Values.pilot.image.repository }}:{{ .Values.pilot.image.tag }}"
        ports:
        - containerPort: 15010
        - containerPort: 15017
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: PILOT_TRACE_SAMPLING
          value: {{ .Values.pilot.traceSampling | quote }}
        resources:
          {{- toYaml .Values.pilot.resources | nindent 10 }}
{{- end }}
```

**Benefits of Helm:**
- ✅ Parameterized (values can change)
- ✅ Conditional resources ({{- if }})
- ✅ Environment-specific values
- ✅ DRY principle (reusable labels via helpers)

### Using Different Values Per Environment

```bash
# Development
helm install istiod ./istiod -f values-dev.yaml

# Production  
helm install istiod ./istiod -f values-prod.yaml
```

**values-dev.yaml:**
```yaml
pilot:
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 512Mi
```

**values-prod.yaml:**
```yaml
pilot:
  replicaCount: 3
  resources:
    requests:
      cpu: 500m
      memory: 2Gi
  autoscaleEnabled: true
  autoscaleMin: 3
  autoscaleMax: 10
```

### ServiceAccount + RBAC

#### **Kubernetes Manifest**

```yaml
# kubernetes/istiod-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: istiod
  namespace: istio-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: istiod-istio-system
rules:
  - apiGroups: ["networking.istio.io"]
    resources: ["*"]
    verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: istiod-istio-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: istiod-istio-system
subjects:
  - kind: ServiceAccount
    name: istiod
    namespace: istio-system
```

#### **Helm Template**

```yaml
# istiod/templates/serviceaccount.yaml
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name }}
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
{{- end }}
```

```yaml
# istiod/templates/clusterrole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: istiod-{{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
rules:
  - apiGroups: ["networking.istio.io"]
    resources: ["*"]
    verbs: ["get", "watch", "list"]
  # Additional rules...
```

```yaml
# istiod/templates/clusterrolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: istiod-{{ .Values.global.istioNamespace }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: istiod-{{ .Values.global.istioNamespace }}
subjects:
  - kind: ServiceAccount
    name: {{ .Values.serviceAccount.name }}
    namespace: {{ .Values.global.istioNamespace }}
```

---

## 3. Istio Gateway Chart

### Chart.yaml
```yaml
apiVersion: v2
name: istio-gateway
description: Istio Ingress/Egress Gateway
version: 1.0.0
appVersion: "1.21.0"
```

### values.yaml
```yaml
name: istio-ingressgateway
namespace: istio-ingress
replicaCount: 3

image:
  repository: istio/proxyv2
  tag: 1.21.0

service:
  type: LoadBalancer
  ports:
  - name: http2
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443

resources:
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
```

### Side-by-Side: Gateway Deployment

#### **Kubernetes Manifest**

```yaml
# kubernetes/gateway-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istio-ingressgateway
  namespace: istio-ingress
spec:
  replicas: 3
  selector:
    matchLabels:
      app: istio-ingressgateway
  template:
    metadata:
      labels:
        app: istio-ingressgateway
      annotations:
        inject.istio.io/templates: "gateway"
    spec:
      containers:
      - name: istio-proxy
        image: istio/proxyv2:1.21.0
        ports:
        - containerPort: 8080
        - containerPort: 8443
```

#### **Helm Template**

```yaml
# istio-gateway/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "istio-gateway.fullname" . }}
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "istio-gateway.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "istio-gateway.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "istio-gateway.selectorLabels" . | nindent 8 }}
      annotations:
        inject.istio.io/templates: "gateway"
    spec:
      containers:
      - name: istio-proxy
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        {{- range .Values.service.ports }}
        - containerPort: {{ .targetPort }}
          name: {{ .name }}
        {{- end }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

---

## Complete Working Example: Bookstore App

### Application Architecture

```
┌────────────────────────────────────────────────────────┐
│                  Bookstore Application                  │
└────────────────────────────────────────────────────────┘

Internet
    │
    ▼
┌─────────────┐
│   Gateway   │ (LoadBalancer)
│  (External) │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│  VirtualService  │ (Traffic Routing)
│    bookstore     │
└──────┬───────────┘
       │
       ├──► /              → frontend
       ├──► /api/books    → books-service
       ├──► /api/reviews  → reviews-service (90% v1, 10% v2)
       └──► /api/ratings  → ratings-service
       
┌─────────────────────────────────────────────────────┐
│              Service Mesh (mTLS)                     │
├──────────────┬──────────────┬──────────────┬────────┤
│   Frontend   │    Books     │   Reviews    │Ratings │
│   ┌──────┐   │   ┌──────┐   │   ┌──────┐   │┌──────┐│
│   │ App  │   │   │ App  │   │   │v1/v2 │   ││ App  ││
│   └──────┘   │   └──────┘   │   └──────┘   │└──────┘│
│   ┌──────┐   │   ┌──────┐   │   ┌──────┐   │┌──────┐│
│   │Envoy │   │   │Envoy │   │   │Envoy │   ││Envoy ││
│   └──────┘   │   └──────┘   │   └──────┘   │└──────┘│
└──────────────┴──────────────┴──────────────┴────────┘
```

### Chart.yaml
```yaml
apiVersion: v2
name: bookstore
description: Bookstore Microservices Application
version: 1.0.0
dependencies:
  - name: istio-base
    version: "1.0.0"
    repository: "file://../istio-base"
    condition: istio.base.enabled
  - name: istiod
    version: "1.0.0"
    repository: "file://../istiod"
    condition: istio.istiod.enabled
```

### values.yaml
```yaml
namespace: bookstore

istio:
  injection:
    enabled: true
  mtls:
    mode: STRICT

gateway:
  enabled: true
  hosts:
    - bookstore.example.com

books:
  enabled: true
  replicaCount: 2
  image:
    repository: your-repo/books-service
    tag: "1.0"

reviews:
  enabled: true
  v1:
    replicaCount: 3
    weight: 90
  v2:
    replicaCount: 1
    weight: 10

trafficManagement:
  retries:
    attempts: 3
    perTryTimeout: 2s
  timeout: 10s
  circuitBreaker:
    enabled: true
    maxConnections: 100
```

### Gateway Configuration

#### **Kubernetes Manifest**

```yaml
# kubernetes/bookstore-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookstore-gateway
  namespace: bookstore
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - bookstore.example.com
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: bookstore-tls
    hosts:
    - bookstore.example.com
```

#### **Helm Template**

```yaml
# bookstore-app/templates/gateway.yaml
{{- if .Values.gateway.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookstore-gateway
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    {{- range .Values.gateway.hosts }}
    - {{ . | quote }}
    {{- end }}
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: {{ .Values.gateway.tls.secretName | default "bookstore-tls" }}
    hosts:
    {{- range .Values.gateway.hosts }}
    - {{ . | quote }}
    {{- end }}
{{- end }}
```

### VirtualService with Canary Routing

#### **Kubernetes Manifest**

```yaml
# kubernetes/bookstore-virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookstore
  namespace: bookstore
spec:
  hosts:
  - bookstore.example.com
  gateways:
  - bookstore-gateway
  http:
  - match:
    - uri:
        prefix: /api/reviews
    route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
    retries:
      attempts: 3
      perTryTimeout: 2s
```

#### **Helm Template**

```yaml
# bookstore-app/templates/virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookstore
  namespace: {{ .Values.namespace }}
spec:
  hosts:
  {{- range .Values.gateway.hosts }}
  - {{ . | quote }}
  {{- end }}
  gateways:
  - bookstore-gateway
  http:
  {{- if .Values.reviews.enabled }}
  - match:
    - uri:
        prefix: /api/reviews
    route:
    - destination:
        host: reviews
        subset: v1
      weight: {{ .Values.reviews.v1.weight }}
    - destination:
        host: reviews
        subset: v2
      weight: {{ .Values.reviews.v2.weight }}
    {{- if .Values.trafficManagement.retries }}
    retries:
      attempts: {{ .Values.trafficManagement.retries.attempts }}
      perTryTimeout: {{ .Values.trafficManagement.retries.perTryTimeout }}
    {{- end }}
    timeout: {{ .Values.trafficManagement.timeout }}
  {{- end }}
```

**Now you can easily adjust canary weights:**

```bash
# Increase v2 traffic to 50%
helm upgrade bookstore ./bookstore-app \
  --set reviews.v1.weight=50 \
  --set reviews.v2.weight=50
```

### DestinationRule with Circuit Breaker

#### **Kubernetes Manifest**

```yaml
# kubernetes/reviews-destinationrule.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
  namespace: bookstore
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http2MaxRequests: 100
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

#### **Helm Template**

```yaml
# bookstore-app/templates/destinationrule.yaml
{{- if .Values.reviews.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
  namespace: {{ .Values.namespace }}
spec:
  host: reviews
  {{- if .Values.trafficManagement.circuitBreaker.enabled }}
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: {{ .Values.trafficManagement.circuitBreaker.maxConnections }}
      http:
        http2MaxRequests: {{ .Values.trafficManagement.circuitBreaker.maxRequests }}
    outlierDetection:
      consecutiveErrors: {{ .Values.trafficManagement.circuitBreaker.consecutiveErrors }}
      interval: 30s
      baseEjectionTime: 30s
  {{- end }}
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
{{- end }}
```

---

## Installation & Testing

### Step-by-Step Installation

```bash
# 1. Create directory structure
mkdir -p istio-charts/{istio-base,istiod,istio-gateway,bookstore-app}

# 2. Install CRDs (Base)
cd istio-charts
helm install istio-base ./istio-base \
  -n istio-system \
  --create-namespace

# Verify CRDs
kubectl get crds | grep istio.io

# 3. Install Control Plane (Istiod)
helm install istiod ./istiod \
  -n istio-system \
  --wait

# Verify Istiod
kubectl get pods -n istio-system
kubectl get svc -n istio-system

# 4. Install Gateway
kubectl create namespace istio-ingress

helm install istio-ingressgateway ./istio-gateway \
  -n istio-ingress

# Get gateway external IP
kubectl get svc -n istio-ingress

# 5. Install Application
helm install bookstore ./bookstore-app \
  --create-namespace

# Verify application
kubectl get pods -n bookstore
kubectl get svc -n bookstore
kubectl get gateway -n bookstore
kubectl get virtualservice -n bookstore
```

### Testing Traffic Flow

```bash
# 1. Get gateway IP
export GATEWAY_IP=$(kubectl get svc istio-ingressgateway \
  -n istio-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# 2. Test frontend
curl -H "Host: bookstore.example.com" http://$GATEWAY_IP/

# 3. Test books API
curl -H "Host: bookstore.example.com" http://$GATEWAY_IP/api/books

# 4. Test canary - reviews API (should see mix of v1 and v2)
for i in {1..10}; do
  curl -H "Host: bookstore.example.com" http://$GATEWAY_IP/api/reviews
done

# 5. Check Istio proxy status
istioctl proxy-status

# 6. View config
istioctl proxy-config routes deploy/books-v1 -n bookstore
```

### Verification Commands

```bash
# Check sidecar injection
kubectl get pods -n bookstore -o jsonpath='{.items[*].spec.containers[*].name}'

# View metrics
kubectl exec -n bookstore deploy/books-v1 -c istio-proxy -- \
  curl localhost:15000/stats/prometheus

# Test mTLS
kubectl exec -n bookstore deploy/books-v1 -c istio-proxy -- \
  curl -s http://localhost:15000/config_dump | grep -o '"mode":"[A-Z]*"'
```

---

## Advanced Patterns

### 1. Blue-Green Deployment

```yaml
# values-blue.yaml
reviews:
  v1:
    weight: 100
  v2:
    weight: 0

# values-green.yaml
reviews:
  v1:
    weight: 0
  v2:
    weight: 100
```

```bash
# Deploy blue (current)
helm upgrade bookstore ./bookstore-app -f values-blue.yaml

# Switch to green
helm upgrade bookstore ./bookstore-app -f values-green.yaml

# Rollback if needed
helm rollback bookstore
```

### 2. Progressive Canary

```bash
# 10% canary
helm upgrade bookstore ./bookstore-app \
  --set reviews.v1.weight=90 \
  --set reviews.v2.weight=10

# Monitor metrics...

# 50% canary
helm upgrade bookstore ./bookstore-app \
  --set reviews.v1.weight=50 \
  --set reviews.v2.weight=50

# Full rollout
helm upgrade bookstore ./bookstore-app \
  --set reviews.v1.weight=0 \
  --set reviews.v2.weight=100
```

### 3. Multi-Environment Setup

```yaml
# values-dev.yaml
namespace: bookstore-dev
gateway:
  hosts:
    - bookstore-dev.example.com
books:
  replicaCount: 1
  resources:
    requests:
      cpu: 50m
      memory: 64Mi

# values-prod.yaml
namespace: bookstore-prod
gateway:
  hosts:
    - bookstore.example.com
books:
  replicaCount: 3
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
```

```bash
# Deploy to dev
helm install bookstore-dev ./bookstore-app -f values-dev.yaml

# Deploy to prod
helm install bookstore-prod ./bookstore-app -f values-prod.yaml
```

### 4. GitOps with ArgoCD

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bookstore
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/istio-charts
    targetRevision: HEAD
    path: bookstore-app
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: bookstore
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Comparison Summary

### Kubernetes Manifests vs Helm Charts

| Feature | Kubernetes YAML | Helm Charts |
|---------|----------------|-------------|
| **Setup** | ✅ Simple | ⚠️ More complex |
| **Reusability** | ❌ Copy/paste | ✅ Packaged |
| **Parameterization** | ❌ Manual find/replace | ✅ values.yaml |
| **Environments** | ❌ Duplicate files | ✅ Multiple values files |
| **Versioning** | ⚠️ Git only | ✅ Chart versions |
| **Rollback** | ❌ Manual | ✅ `helm rollback` |
| **Dependencies** | ❌ Manual order | ✅ Automatic |
| **Testing** | ❌ Manual apply | ✅ `helm test` |
| **Templating** | ❌ None | ✅ Go templates |
| **Best For** | Learning, Simple | Production, Scale |

### When to Use Each

**Use Kubernetes Manifests When:**
- Learning Kubernetes/Istio basics
- Very simple deployments
- One-time setups
- No need for reusability

**Use Helm Charts When:**
- Multiple environments (dev/staging/prod)
- Need to parameterize configurations
- Want rollback capabilities
- Building reusable components
- Production deployments
- GitOps workflows

---

## Quick Reference

### Installation Commands

```bash
# Kubernetes
kubectl apply -f kubernetes/

# Helm
helm install <release> ./chart-name

# Helm with custom values
helm install <release> ./chart-name -f values-prod.yaml

# Helm upgrade
helm upgrade <release> ./chart-name --reuse-values

# Helm rollback
helm rollback <release> <revision>

# Helm template (dry-run)
helm template <release> ./chart-name

# Helm list
helm list -n <namespace>
```

### Debugging Commands

```bash
# Kubernetes
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl get events --sort-by='.lastTimestamp'

# Helm
helm get values <release>
helm get manifest <release>
helm history <release>

# Istio
istioctl analyze
istioctl proxy-status
istioctl describe pod <pod-name>
istioctl proxy-config routes <pod-name>
```

---

## Conclusion

### Key Takeaways

1. **Helm provides powerful templating** - Reuse configurations across environments
2. **Custom charts give full control** - Understand every resource
3. **Start simple, evolve gradually** - Begin with Kubernetes, move to Helm
4. **Version everything** - Charts, values, and deployments
5. **Test thoroughly** - Use `helm template` and dry-runs

### Next Steps

1. Build your own base chart
2. Customize for your organization
3. Create environment-specific values
4. Integrate with CI/CD
5. Document your charts
6. Share with your team

---

**Repository Structure Example:**

```
my-istio-charts/
├── README.md
├── .gitignore
├── charts/
│   ├── istio-base/
│   ├── istiod/
│   ├── istio-gateway/
│   └── bookstore-app/
├── values/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── examples/
    ├── basic-app/
    ├── canary-deployment/
    └── multi-cluster/
```

Happy Helming! 🎉