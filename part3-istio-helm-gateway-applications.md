# Building Custom Istio Helm Charts from Scratch
## Part 3: Gateway Chart, Applications & Production Patterns

---

## Table of Contents - Part 3
1. [Gateway Chart](#gateway-chart)
2. [Complete Bookstore Application](#complete-bookstore-application)
3. [Traffic Management Patterns](#traffic-management-patterns)
4. [Security Configurations](#security-configurations)
5. [Observability](#observability)
6. [Production Deployment](#production-deployment)
7. [Multi-Environment Setup](#multi-environment-setup)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Gateway Chart

### Gateway Overview

Gateways are specialized Envoy proxies deployed at the edge of the mesh to handle ingress and egress traffic.

```
┌──────────────────────────────────────────────────────────┐
│                    Gateway Architecture                   │
└──────────────────────────────────────────────────────────┘

External Traffic                        Internal Traffic
     │                                        │
     ▼                                        ▼
┌─────────────────┐                  ┌──────────────────┐
│ Ingress Gateway │                  │ Egress Gateway   │
│  LoadBalancer   │                  │   ClusterIP      │
│   :80, :443     │                  │    :443          │
└────────┬────────┘                  └────────┬─────────┘
         │                                    │
         │ TLS Termination                   │ TLS Origination
         │ Virtual Host Routing              │ Access Control
         │                                    │
         ▼                                    ▼
    ┌─────────────────────────────────────────────────┐
    │            Mesh Internal Services               │
    │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐        │
    │  │App-A │  │App-B │  │App-C │  │App-D │        │
    │  └──────┘  └──────┘  └──────┘  └──────┘        │
    └─────────────────────────────────────────────────┘
```

### Chart Structure

```
charts/istio-gateway/
├── Chart.yaml
├── values.yaml
├── values-ingress.yaml
├── values-egress.yaml
├── README.md
├── templates/
│   ├── _helpers.tpl
│   ├── NOTES.txt
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── role.yaml
│   ├── rolebinding.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── horizontalpodautoscaler.yaml
│   ├── poddisruptionbudget.yaml
│   └── networkpolicy.yaml
└── tests/
    └── test-gateway.yaml
```

### Chart.yaml

```yaml
# charts/istio-gateway/Chart.yaml
apiVersion: v2
name: istio-gateway
description: |
  Istio Gateway - Ingress and Egress gateway for managing
  traffic entering and leaving the service mesh.

type: application
version: 1.0.0
appVersion: "1.21.0"

keywords:
  - istio
  - gateway
  - ingress
  - egress
  - load-balancer

home: https://istio.io
sources:
  - https://github.com/istio/istio

maintainers:
  - name: Platform Team
    email: platform@yourcompany.com
```

### values.yaml

```yaml
# charts/istio-gateway/values.yaml

# Gateway type: ingress or egress
gatewayType: ingress

# Gateway name
name: istio-ingressgateway

# Namespace for gateway
namespace: istio-ingress

# Global settings
global:
  hub: docker.io/istio
  tag: 1.21.0
  imagePullPolicy: IfNotPresent
  imagePullSecrets: []

# ===== DEPLOYMENT =====
replicaCount: 3

image:
  repository: proxyv2
  tag: ""  # Uses global.tag if not set
  pullPolicy: ""  # Uses global.imagePullPolicy if not set

# ===== SERVICE =====
service:
  type: LoadBalancer
  # For cloud providers that support annotations
  annotations: {}
  # Example AWS annotations:
  # service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  # service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
  # Example GCP annotations:
  # cloud.google.com/load-balancer-type: "Internal"
  
  loadBalancerIP: ""
  loadBalancerSourceRanges: []
  # - "10.0.0.0/8"
  
  externalTrafficPolicy: Local  # or Cluster
  sessionAffinity: None  # or ClientIP
  
  ports:
  - name: status-port
    port: 15021
    targetPort: 15021
    protocol: TCP
  - name: http2
    port: 80
    targetPort: 8080
    protocol: TCP
    nodePort: 30080  # Optional for NodePort
  - name: https
    port: 443
    targetPort: 8443
    protocol: TCP
    nodePort: 30443  # Optional for NodePort
  - name: tcp
    port: 31400
    targetPort: 31400
    protocol: TCP
  - name: tls
    port: 15443
    targetPort: 15443
    protocol: TCP

# ===== RESOURCES =====
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi

# ===== AUTOSCALING =====
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

# ===== POD DISRUPTION BUDGET =====
podDisruptionBudget:
  enabled: true
  minAvailable: 2
  # maxUnavailable: 1

# ===== SECURITY CONTEXT =====
podSecurityContext:
  runAsUser: 1337
  runAsGroup: 1337
  runAsNonRoot: true
  fsGroup: 1337

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  privileged: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1337
  runAsGroup: 1337

# ===== POD CONFIGURATION =====
podAnnotations:
  prometheus.io/port: "15020"
  prometheus.io/scrape: "true"
  prometheus.io/path: "/stats/prometheus"
  inject.istio.io/templates: "gateway"

nodeSelector: {}
tolerations: []
affinity: {}

# ===== SERVICE ACCOUNT =====
serviceAccount:
  create: true
  name: ""
  annotations: {}

# ===== ENVIRONMENT VARIABLES =====
env:
  # Istio meta router mode for gateways
  ISTIO_META_ROUTER_MODE: "sni-dnat"
  ISTIO_META_REQUESTED_NETWORK_VIEW: ""
  ISTIO_META_UNPRIVILEGED_POD: "true"

# ===== NETWORK POLICY =====
networkPolicy:
  enabled: false
  # Ingress rules
  ingress: []
  # - from:
  #   - namespaceSelector:
  #       matchLabels:
  #         name: production
  # Egress rules  
  egress: []
  # - to:
  #   - namespaceSelector: {}
```

### Deployment Template

```yaml
# charts/istio-gateway/templates/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "istio-gateway.fullname" . }}
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "istio-gateway.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  
  strategy:
    rollingUpdate:
      maxSurge: 100%
      maxUnavailable: 25%
  
  selector:
    matchLabels:
      {{- include "istio-gateway.selectorLabels" . | nindent 6 }}
  
  template:
    metadata:
      labels:
        {{- include "istio-gateway.selectorLabels" . | nindent 8 }}
        sidecar.istio.io/inject: "false"
      annotations:
        {{- toYaml .Values.podAnnotations | nindent 8 }}
    
    spec:
      serviceAccountName: {{ include "istio-gateway.serviceAccountName" . }}
      
      {{- with .Values.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      
      containers:
      - name: istio-proxy
        image: "{{ .Values.global.hub }}/{{ .Values.image.repository }}:{{ .Values.image.tag | default .Values.global.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy | default .Values.global.imagePullPolicy }}
        
        ports:
        {{- range .Values.service.ports }}
        - containerPort: {{ .targetPort }}
          protocol: {{ .protocol }}
          name: {{ .name }}
        {{- end }}
        - containerPort: 15090
          protocol: TCP
          name: http-envoy-prom
        
        env:
        {{- range $key, $value := .Values.env }}
        - name: {{ $key }}
          value: {{ $value | quote }}
        {{- end }}
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: INSTANCE_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
        
        readinessProbe:
          httpGet:
            path: /healthz/ready
            port: 15021
            scheme: HTTP
          initialDelaySeconds: 1
          periodSeconds: 2
          timeoutSeconds: 1
          successThreshold: 1
          failureThreshold: 30
        
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        
        {{- with .Values.securityContext }}
        securityContext:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        
        volumeMounts:
        - name: workload-socket
          mountPath: /var/run/secrets/workload-spiffe-uds
        - name: workload-certs
          mountPath: /var/run/secrets/workload-spiffe-credentials
        - name: istio-envoy
          mountPath: /etc/istio/proxy
        - name: config-volume
          mountPath: /etc/istio/config
        - mountPath: /var/run/secrets/tokens
          name: istio-token
        - name: istio-data
          mountPath: /var/lib/istio/data
        - name: podinfo
          mountPath: /etc/istio/pod
        - name: ingressgateway-certs
          mountPath: "/etc/istio/ingressgateway-certs"
          readOnly: true
        - name: ingressgateway-ca-certs
          mountPath: "/etc/istio/ingressgateway-ca-certs"
          readOnly: true
      
      volumes:
      - name: workload-socket
        emptyDir: {}
      - name: workload-certs
        emptyDir: {}
      - name: istio-envoy
        emptyDir: {}
      - name: istio-data
        emptyDir: {}
      - name: istio-token
        projected:
          sources:
          - serviceAccountToken:
              path: istio-token
              expirationSeconds: 43200
              audience: istio-ca
      - name: config-volume
        configMap:
          name: istio
          optional: true
      - name: podinfo
        downwardAPI:
          items:
          - path: "labels"
            fieldRef:
              fieldPath: metadata.labels
          - path: "annotations"
            fieldRef:
              fieldPath: metadata.annotations
      - name: ingressgateway-certs
        secret:
          secretName: "istio-ingressgateway-certs"
          optional: true
      - name: ingressgateway-ca-certs
        secret:
          secretName: "istio-ingressgateway-ca-certs"
          optional: true
      
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- else }}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  {{- include "istio-gateway.selectorLabels" . | nindent 18 }}
              topologyKey: kubernetes.io/hostname
      {{- end }}
      
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      
      {{- with .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### Service Template

```yaml
# charts/istio-gateway/templates/service.yaml

apiVersion: v1
kind: Service
metadata:
  name: {{ include "istio-gateway.fullname" . }}
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "istio-gateway.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  
  {{- if .Values.service.loadBalancerIP }}
  loadBalancerIP: {{ .Values.service.loadBalancerIP }}
  {{- end }}
  
  {{- if .Values.service.loadBalancerSourceRanges }}
  loadBalancerSourceRanges:
    {{- toYaml .Values.service.loadBalancerSourceRanges | nindent 4 }}
  {{- end }}
  
  {{- if .Values.service.externalTrafficPolicy }}
  externalTrafficPolicy: {{ .Values.service.externalTrafficPolicy }}
  {{- end }}
  
  {{- if .Values.service.sessionAffinity }}
  sessionAffinity: {{ .Values.service.sessionAffinity }}
  {{- end }}
  
  selector:
    {{- include "istio-gateway.selectorLabels" . | nindent 4 }}
  
  ports:
    {{- range .Values.service.ports }}
    - port: {{ .port }}
      targetPort: {{ .targetPort }}
      protocol: {{ .protocol }}
      name: {{ .name }}
      {{- if and (eq $.Values.service.type "NodePort") .nodePort }}
      nodePort: {{ .nodePort }}
      {{- end }}
    {{- end }}
```

### HorizontalPodAutoscaler

```yaml
# charts/istio-gateway/templates/horizontalpodautoscaler.yaml

{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "istio-gateway.fullname" . }}
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "istio-gateway.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "istio-gateway.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
  {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
  {{- end }}
{{- end }}
```

### PodDisruptionBudget

```yaml
# charts/istio-gateway/templates/poddisruptionbudget.yaml

{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "istio-gateway.fullname" . }}
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "istio-gateway.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "istio-gateway.selectorLabels" . | nindent 6 }}
  {{- if .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  {{- end }}
  {{- if .Values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  {{- end }}
{{- end }}
```

### _helpers.tpl

```yaml
# charts/istio-gateway/templates/_helpers.tpl

{{- define "istio-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "istio-gateway.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Values.name .Values.nameOverride }}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "istio-gateway.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ include "istio-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ .Values.name }}
istio: {{ .Values.gatewayType }}gateway
{{- end }}

{{- define "istio-gateway.selectorLabels" -}}
app: {{ .Values.name }}
istio: {{ .Values.gatewayType }}gateway
{{- end }}

{{- define "istio-gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "istio-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
```

---

## Complete Bookstore Application

### Application Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                   Bookstore Application                        │
└───────────────────────────────────────────────────────────────┘

                    Internet
                        │
                        ▼
              ┌──────────────────┐
              │ Ingress Gateway  │
              │  LoadBalancer    │
              │   80/443         │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │   Gateway CRD    │
              │  bookstore.com   │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │ VirtualService   │
              │  Route Rules     │
              └────────┬─────────┘
                       │
      ┌────────────────┼────────────────┬───────────────┐
      │                │                │               │
      ▼                ▼                ▼               ▼
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Frontend │    │  Books   │    │ Reviews  │    │ Ratings  │
│  React   │───►│   API    │◄───│   API    │◄───│   API    │
│   Pod    │    │   Pod    │    │  v1/v2   │    │   Pod    │
└──────────┘    └──────────┘    └─────┬────┘    └──────────┘
                                      │
                               Canary: 90% v1
                                      10% v2
```

### Chart Structure

```
charts/bookstore/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-staging.yaml
├── values-prod.yaml
├── README.md
├── templates/
│   ├── _helpers.tpl
│   ├── NOTES.txt
│   ├── namespace.yaml
│   │
│   ├── deployments/
│   │   ├── frontend.yaml
│   │   ├── books.yaml
│   │   ├── reviews-v1.yaml
│   │   ├── reviews-v2.yaml
│   │   └── ratings.yaml
│   │
│   ├── services/
│   │   ├── frontend.yaml
│   │   ├── books.yaml
│   │   ├── reviews.yaml
│   │   └── ratings.yaml
│   │
│   ├── istio/
│   │   ├── gateway.yaml
│   │   ├── virtualservice.yaml
│   │   ├── destinationrule-books.yaml
│   │   ├── destinationrule-reviews.yaml
│   │   └── peerauthentication.yaml
│   │
│   └── monitoring/
│       ├── servicemonitor.yaml
│       └── prometheusrule.yaml
│
└── tests/
    └── test-connectivity.yaml
```

### Chart.yaml

```yaml
# charts/bookstore/Chart.yaml
apiVersion: v2
name: bookstore
description: |
  Complete microservices bookstore application with Istio service mesh.
  Demonstrates traffic management, security, and observability features.

type: application
version: 1.0.0
appVersion: "1.0"

dependencies:
  - name: istio-base
    version: "1.0.0"
    repository: "file://../istio-base"
    condition: istio.base.enabled
  - name: istiod
    version: "1.0.0"
    repository: "file://../istiod"
    condition: istio.istiod.enabled

keywords:
  - microservices
  - istio
  - bookstore
  - demo
  - example

maintainers:
  - name: Platform Team
```

### values.yaml (Complete Application)

```yaml
# charts/bookstore/values.yaml

# ===== NAMESPACE =====
namespace: bookstore

# ===== ISTIO DEPENDENCIES =====
istio:
  base:
    enabled: false  # Install separately
  istiod:
    enabled: false  # Install separately
  
  # Enable sidecar injection
  injection:
    enabled: true
  
  # mTLS mode
  mtls:
    mode: STRICT  # STRICT, PERMISSIVE, DISABLE

# ===== GATEWAY =====
gateway:
  enabled: true
  hosts:
    - bookstore.example.com
    - www.bookstore.example.com
  
  tls:
    enabled: true
    secretName: bookstore-tls
    # Create secret with:
    # kubectl create secret tls bookstore-tls \
    #   --cert=path/to/tls.crt \
    #   --key=path/to/tls.key \
    #   -n bookstore

# ===== FRONTEND SERVICE =====
frontend:
  enabled: true
  replicaCount: 2
  
  image:
    repository: your-registry/bookstore-frontend
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  
  service:
    port: 80
    targetPort: 3000
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  env:
    - name: BOOKS_API_URL
      value: "http://books"
    - name: REVIEWS_API_URL
      value: "http://reviews"

# ===== BOOKS SERVICE =====
books:
  enabled: true
  replicaCount: 2
  
  image:
    repository: your-registry/books-service
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  
  service:
    port: 80
    targetPort: 8080
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  env:
    - name: DATABASE_URL
      value: "postgresql://books-db:5432/books"
    - name: LOG_LEVEL
      value: "info"

# ===== REVIEWS SERVICE (CANARY) =====
reviews:
  enabled: true
  
  # Version 1 (stable)
  v1:
    replicaCount: 3
    image:
      repository: your-registry/reviews-service
      tag: "1.0.0"
    weight: 90  # 90% traffic
  
  # Version 2 (canary)
  v2:
    replicaCount: 1
    image:
      repository: your-registry/reviews-service
      tag: "2.0.0"
    weight: 10  # 10% traffic
  
  service:
    port: 80
    targetPort: 8080
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  env:
    - name: RATINGS_API_URL
      value: "http://ratings"

# ===== RATINGS SERVICE =====
ratings:
  enabled: true
  replicaCount: 2
  
  image:
    repository: your-registry/ratings-service
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  
  service:
    port: 80
    targetPort: 8080
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

# ===== TRAFFIC MANAGEMENT =====
trafficManagement:
  # Retry settings
  retries:
    enabled: true
    attempts: 3
    perTryTimeout: 2s
    retryOn: "5xx,reset,connect-failure,refused-stream"
  
  # Timeout settings
  timeout: 10s
  
  # Circuit breaker
  circuitBreaker:
    enabled: true
    maxConnections: 100
    maxPendingRequests: 50
    maxRequests: 100
    consecutiveErrors: 5
    interval: 30s
    baseEjectionTime: 30s
  
  # Fault injection (testing)
  faultInjection:
    enabled: false
    delay:
      percentage: 10
      fixedDelay: 5s
    abort:
      percentage: 5
      httpStatus: 503

# ===== MONITORING =====
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 15s
  
  prometheusRules:
    enabled: true
    # Alert when error rate > 5%
    highErrorRate:
      threshold: 5
    # Alert when p95 latency > 1s
    highLatency:
      threshold: 1000

# ===== GLOBAL IMAGE SETTINGS =====
imagePullSecrets: []
# - name: regcred
```

### Deployment Templates

#### Frontend Deployment

```yaml
# charts/bookstore/templates/deployments/frontend.yaml

{{- if .Values.frontend.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
    app: frontend
    version: v1
spec:
  replicas: {{ .Values.frontend.replicaCount }}
  selector:
    matchLabels:
      app: frontend
      version: v1
  template:
    metadata:
      labels:
        app: frontend
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
      - name: frontend
        image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
        imagePullPolicy: {{ .Values.frontend.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.frontend.service.targetPort }}
          name: http
          protocol: TCP
        env:
        {{- range .Values.frontend.env }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
        resources:
          {{- toYaml .Values.frontend.resources | nindent 10 }}
        livenessProbe:
          httpGet:
            path: /health
            port: {{ .Values.frontend.service.targetPort }}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: {{ .Values.frontend.service.targetPort }}
          initialDelaySeconds: 10
          periodSeconds: 5
{{- end }}
```

#### Reviews Deployment (with Canary)

```yaml
# charts/bookstore/templates/deployments/reviews-v1.yaml

{{- if .Values.reviews.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v1
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
    app: reviews
    version: v1
spec:
  replicas: {{ .Values.reviews.v1.replicaCount }}
  selector:
    matchLabels:
      app: reviews
      version: v1
  template:
    metadata:
      labels:
        app: reviews
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: reviews
        image: "{{ .Values.reviews.v1.image.repository }}:{{ .Values.reviews.v1.image.tag }}"
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: {{ .Values.reviews.service.targetPort }}
          name: http
        env:
        - name: SERVICE_VERSION
          value: "v1"
        {{- range .Values.reviews.env }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
        resources:
          {{- toYaml .Values.reviews.resources | nindent 10 }}
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v2
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
    app: reviews
    version: v2
spec:
  replicas: {{ .Values.reviews.v2.replicaCount }}
  selector:
    matchLabels:
      app: reviews
      version: v2
  template:
    metadata:
      labels:
        app: reviews
        version: v2
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: reviews
        image: "{{ .Values.reviews.v2.image.repository }}:{{ .Values.reviews.v2.image.tag }}"
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: {{ .Values.reviews.service.targetPort }}
          name: http
        env:
        - name: SERVICE_VERSION
          value: "v2"
        - name: ENABLE_NEW_FEATURES
          value: "true"
        {{- range .Values.reviews.env }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
        resources:
          {{- toYaml .Values.reviews.resources | nindent 10 }}
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
{{- end }}
```

### Service Templates

```yaml
# charts/bookstore/templates/services/reviews.yaml

{{- if .Values.reviews.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: reviews
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
    app: reviews
spec:
  type: ClusterIP
  ports:
  - port: {{ .Values.reviews.service.port }}
    targetPort: {{ .Values.reviews.service.targetPort }}
    protocol: TCP
    name: http
  selector:
    app: reviews
{{- end }}
```

### Istio Configuration Templates

#### Gateway

```yaml
# charts/bookstore/templates/istio/gateway.yaml

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
    {{- if .Values.gateway.tls.enabled }}
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: {{ .Values.gateway.tls.secretName }}
    hosts:
    {{- range .Values.gateway.hosts }}
    - {{ . | quote }}
    {{- end }}
    {{- end }}
{{- end }}
```

#### VirtualService (Complete Routing)

```yaml
# charts/bookstore/templates/istio/virtualservice.yaml

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookstore
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
spec:
  hosts:
  {{- range .Values.gateway.hosts }}
  - {{ . | quote }}
  {{- end }}
  gateways:
  - bookstore-gateway
  http:
  # ===== FRONTEND ROUTES =====
  {{- if .Values.frontend.enabled }}
  - match:
    - uri:
        prefix: /static/
    - uri:
        exact: /
    route:
    - destination:
        host: frontend
        port:
          number: {{ .Values.frontend.service.port }}
  {{- end }}
  
  # ===== BOOKS API ROUTES =====
  {{- if .Values.books.enabled }}
  - match:
    - uri:
        prefix: /api/books
    rewrite:
      uri: /books
    route:
    - destination:
        host: books
        port:
          number: {{ .Values.books.service.port }}
    {{- if .Values.trafficManagement.timeout }}
    timeout: {{ .Values.trafficManagement.timeout }}
    {{- end }}
    {{- if .Values.trafficManagement.retries.enabled }}
    retries:
      attempts: {{ .Values.trafficManagement.retries.attempts }}
      perTryTimeout: {{ .Values.trafficManagement.retries.perTryTimeout }}
      retryOn: {{ .Values.trafficManagement.retries.retryOn }}
    {{- end }}
    {{- if .Values.trafficManagement.faultInjection.enabled }}
    fault:
      {{- if .Values.trafficManagement.faultInjection.delay }}
      delay:
        percentage:
          value: {{ .Values.trafficManagement.faultInjection.delay.percentage }}
        fixedDelay: {{ .Values.trafficManagement.faultInjection.delay.fixedDelay }}
      {{- end }}
      {{- if .Values.trafficManagement.faultInjection.abort }}
      abort:
        percentage:
          value: {{ .Values.trafficManagement.faultInjection.abort.percentage }}
        httpStatus: {{ .Values.trafficManagement.faultInjection.abort.httpStatus }}
      {{- end }}
    {{- end }}
  {{- end }}
  
  # ===== REVIEWS API ROUTES (CANARY) =====
  {{- if .Values.reviews.enabled }}
  - match:
    - uri:
        prefix: /api/reviews
    rewrite:
      uri: /reviews
    route:
    - destination:
        host: reviews
        subset: v1
        port:
          number: {{ .Values.reviews.service.port }}
      weight: {{ .Values.reviews.v1.weight }}
    - destination:
        host: reviews
        subset: v2
        port:
          number: {{ .Values.reviews.service.port }}
      weight: {{ .Values.reviews.v2.weight }}
    {{- if .Values.trafficManagement.timeout }}
    timeout: {{ .Values.trafficManagement.timeout }}
    {{- end }}
    {{- if .Values.trafficManagement.retries.enabled }}
    retries:
      attempts: {{ .Values.trafficManagement.retries.attempts }}
      perTryTimeout: {{ .Values.trafficManagement.retries.perTryTimeout }}
      retryOn: {{ .Values.trafficManagement.retries.retryOn }}
    {{- end }}
  {{- end }}
  
  # ===== RATINGS API ROUTES =====
  {{- if .Values.ratings.enabled }}
  - match:
    - uri:
        prefix: /api/ratings
    rewrite:
      uri: /ratings
    route:
    - destination:
        host: ratings
        port:
          number: {{ .Values.ratings.service.port }}
    timeout: 5s
  {{- end }}
```

#### DestinationRule (with Circuit Breaker)

```yaml
# charts/bookstore/templates/istio/destinationrule-reviews.yaml

{{- if .Values.reviews.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
spec:
  host: reviews
  
  {{- if .Values.trafficManagement.circuitBreaker.enabled }}
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: {{ .Values.trafficManagement.circuitBreaker.maxConnections }}
      http:
        http1MaxPendingRequests: {{ .Values.trafficManagement.circuitBreaker.maxPendingRequests }}
        http2MaxRequests: {{ .Values.trafficManagement.circuitBreaker.maxRequests }}
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: {{ .Values.trafficManagement.circuitBreaker.consecutiveErrors }}
      interval: {{ .Values.trafficManagement.circuitBreaker.interval }}
      baseEjectionTime: {{ .Values.trafficManagement.circuitBreaker.baseEjectionTime }}
      maxEjectionPercent: 50
      minHealthPercent: 40
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

#### PeerAuthentication (mTLS)

```yaml
# charts/bookstore/templates/istio/peerauthentication.yaml

apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
spec:
  mtls:
    mode: {{ .Values.istio.mtls.mode }}
```

---

## Traffic Management Patterns

### Pattern 1: Canary Deployment

Gradually shift traffic from old to new version.

```yaml
# Start: 100% v1
reviews:
  v1:
    weight: 100
  v2:
    weight: 0

# Step 1: 90% v1, 10% v2
helm upgrade bookstore ./bookstore \
  --set reviews.v1.weight=90 \
  --set reviews.v2.weight=10

# Step 2: 50-50 split
helm upgrade bookstore ./bookstore \
  --set reviews.v1.weight=50 \
  --set reviews.v2.weight=50

# Final: 100% v2
helm upgrade bookstore ./bookstore \
  --set reviews.v1.weight=0 \
  --set reviews.v2.weight=100
```

### Pattern 2: Blue-Green Deployment

Instant switch between versions.

```yaml
# Blue (current) - values-blue.yaml
reviews:
  v1:
    replicaCount: 3
    weight: 100
  v2:
    replicaCount: 3
    weight: 0

# Green (new) - values-green.yaml
reviews:
  v1:
    replicaCount: 3
    weight: 0
  v2:
    replicaCount: 3
    weight: 100
```

```bash
# Deploy blue
helm install bookstore ./bookstore -f values-blue.yaml

# Switch to green
helm upgrade bookstore ./bookstore -f values-green.yaml

# Instant traffic switch!
```

### Pattern 3: A/B Testing

Route based on headers/cookies.

```yaml
# charts/bookstore/templates/istio/virtualservice-ab.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-ab-test
spec:
  hosts:
  - reviews
  http:
  # Beta users get v2
  - match:
    - headers:
        x-user-group:
          exact: "beta"
    route:
    - destination:
        host: reviews
        subset: v2
  # Everyone else gets v1
  - route:
    - destination:
        host: reviews
        subset: v1
```

### Pattern 4: Dark Launch (Traffic Mirroring)

Send duplicate traffic to new version for testing.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews-mirror
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 100
    mirror:
      host: reviews
      subset: v2
    mirrorPercentage:
      value: 100.0  # Mirror 100% of traffic to v2
```

---

## Security Configurations

### 1. Strict mTLS

```yaml
# Namespace-wide mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: bookstore
spec:
  mtls:
    mode: STRICT
```

### 2. Authorization Policies

#### Deny All (Default Deny)

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: bookstore
spec:
  {}  # Empty spec = deny all
```

#### Allow Frontend to Books

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-to-books
  namespace: bookstore
spec:
  selector:
    matchLabels:
      app: books
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/bookstore/sa/frontend"
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/books/*"]
```

#### JWT Authentication

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: bookstore
spec:
  selector:
    matchLabels:
      app: books
  jwtRules:
  - issuer: "https://auth.bookstore.com"
    jwksUri: "https://auth.bookstore.com/.well-known/jwks.json"
    audiences:
    - "bookstore-api"
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: bookstore
spec:
  selector:
    matchLabels:
      app: books
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["*"]
    when:
    - key: request.auth.claims[role]
      values: ["user", "admin"]
```

---

## Observability

### ServiceMonitor (Prometheus)

```yaml
# charts/bookstore/templates/monitoring/servicemonitor.yaml

{{- if and .Values.monitoring.enabled .Values.monitoring.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: bookstore
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      app: reviews
  endpoints:
  - port: http
    interval: {{ .Values.monitoring.serviceMonitor.interval }}
    path: /metrics
  namespaceSelector:
    matchNames:
    - {{ .Values.namespace }}
{{- end }}
```

### PrometheusRule (Alerts)

```yaml
# charts/bookstore/templates/monitoring/prometheusrule.yaml

{{- if and .Values.monitoring.enabled .Values.monitoring.prometheusRules.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: bookstore-alerts
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "bookstore.labels" . | nindent 4 }}
spec:
  groups:
  - name: bookstore.rules
    interval: 30s
    rules:
    # High error rate alert
    - alert: HighErrorRate
      expr: |
        (
          sum(rate(istio_requests_total{
            destination_service_name="reviews",
            response_code=~"5.."
          }[5m]))
          /
          sum(rate(istio_requests_total{
            destination_service_name="reviews"
          }[5m]))
        ) * 100 > {{ .Values.monitoring.prometheusRules.highErrorRate.threshold }}
      for: 5m
      labels:
        severity: warning
        service: reviews
      annotations:
        summary: "High error rate for reviews service"
        description: "Error rate is {{`{{ $value }}`}}%"
    
    # High latency alert
    - alert: HighLatency
      expr: |
        histogram_quantile(0.95,
          sum(rate(istio_request_duration_milliseconds_bucket{
            destination_service_name="reviews"
          }[5m])) by (le)
        ) > {{ .Values.monitoring.prometheusRules.highLatency.threshold }}
      for: 5m
      labels:
        severity: warning
        service: reviews
      annotations:
        summary: "High latency for reviews service"
        description: "P95 latency is {{`{{ $value }}`}}ms"
{{- end }}
```

---

## Production Deployment

### Complete Installation Script

```bash
#!/bin/bash
# install-bookstore.sh

set -e

echo "🚀 Installing Bookstore Application"

# Configuration
NAMESPACE="bookstore"
ENVIRONMENT=${1:-"prod"}  # dev, staging, prod

echo "📦 Environment: $ENVIRONMENT"

# Step 1: Install Istio Base
echo "1️⃣  Installing Istio Base (CRDs)..."
helm upgrade --install istio-base ../istio-base \
  -n istio-system \
  --create-namespace \
  --wait

# Step 2: Install Istiod
echo "2️⃣  Installing Istiod (Control Plane)..."
helm upgrade --install istiod ../istiod \
  -n istio-system \
  --wait \
  --timeout 10m

# Step 3: Install Gateway
echo "3️⃣  Installing Istio Gateway..."
helm upgrade --install istio-ingressgateway ../istio-gateway \
  -n istio-ingress \
  --create-namespace \
  --wait

# Step 4: Wait for gateway external IP
echo "⏳ Waiting for gateway external IP..."
kubectl wait --for=condition=ready pod \
  -l app=istio-ingressgateway \
  -n istio-ingress \
  --timeout=300s

# Step 5: Create TLS secret (if needed)
if [ "$ENVIRONMENT" == "prod" ]; then
  echo "🔒 Creating TLS secret..."
  kubectl create namespace $NAMESPACE || true
  kubectl create secret tls bookstore-tls \
    --cert=certs/tls.crt \
    --key=certs/tls.key \
    -n $NAMESPACE || echo "Secret already exists"
fi

# Step 6: Install application
echo "4️⃣  Installing Bookstore Application..."
helm upgrade --install bookstore ./bookstore \
  -f values-${ENVIRONMENT}.yaml \
  --create-namespace \
  --wait \
  --timeout 5m

# Step 7: Verification
echo "✅ Verifying installation..."
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE
kubectl get gateway -n $NAMESPACE
kubectl get virtualservice -n $NAMESPACE

# Step 8: Get gateway URL
GATEWAY_IP=$(kubectl get svc istio-ingressgateway \
  -n istio-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo ""
echo "✨ Installation Complete!"
echo "📍 Gateway IP: $GATEWAY_IP"
echo "🌐 Application URL: http://$GATEWAY_IP (or https if TLS enabled)"
echo ""
echo "📊 Next steps:"
echo "  - Update DNS to point to $GATEWAY_IP"
echo "  - Monitor with: kubectl logs -n $NAMESPACE -l app=reviews -f"
echo "  - Check Istio proxy: istioctl proxy-status"
```

---

## Multi-Environment Setup

### values-dev.yaml

```yaml
namespace: bookstore-dev

gateway:
  hosts:
    - bookstore-dev.example.com
  tls:
    enabled: false

frontend:
  replicaCount: 1
  image:
    tag: "dev"
  resources:
    requests:
      cpu: 50m
      memory: 64Mi

books:
  replicaCount: 1
  resources:
    requests:
      cpu: 50m
      memory: 64Mi

reviews:
  v1:
    replicaCount: 1
    weight: 100
  v2:
    replicaCount: 0
    weight: 0

ratings:
  replicaCount: 1

trafficManagement:
  circuitBreaker:
    enabled: false
  faultInjection:
    enabled: true  # Test failures in dev

monitoring:
  enabled: false
```

### values-prod.yaml

```yaml
namespace: bookstore

gateway:
  hosts:
    - bookstore.example.com
    - www.bookstore.example.com
  tls:
    enabled: true
    secretName: bookstore-tls

frontend:
  replicaCount: 3
  image:
    tag: "1.0.0"
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

books:
  replicaCount: 3
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

reviews:
  v1:
    replicaCount: 3
    weight: 90
  v2:
    replicaCount: 2
    weight: 10
  resources:
    requests:
      cpu: 200m
      memory: 256Mi

ratings:
  replicaCount: 3

istio:
  mtls:
    mode: STRICT

trafficManagement:
  retries:
    enabled: true
    attempts: 3
  circuitBreaker:
    enabled: true
  faultInjection:
    enabled: false

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
  prometheusRules:
    enabled: true
```

---

## Troubleshooting Guide

### Common Issues

#### 1. Sidecar Not Injected

```bash
# Check namespace label
kubectl get namespace bookstore --show-labels

# Label namespace
kubectl label namespace bookstore istio-injection=enabled

# Verify webhook
kubectl get mutatingwebhookconfigurations | grep istio

# Restart pods
kubectl rollout restart deployment -n bookstore
```

#### 2. 503 Service Unavailable

```bash
# Check if service exists
kubectl get svc -n bookstore

# Check endpoints
kubectl get endpoints -n bookstore

# Verify DestinationRule subsets match pod labels
kubectl get pods -n bookstore --show-labels
kubectl get destinationrule reviews -n bookstore -o yaml

# Check Envoy config
istioctl proxy-config routes deploy/frontend -n bookstore
```

#### 3. mTLS Issues

```bash
# Check PeerAuthentication
kubectl get peerauthentication -n bookstore

# Verify certificates
istioctl proxy-config secret deploy/frontend -n bookstore

# Test connection
kubectl exec -it deploy/frontend -n bookstore -c istio-proxy -- \
  curl -v http://books
```

#### 4. Gateway Not Accessible

```bash
# Check gateway status
kubectl get gateway -n bookstore
kubectl describe gateway bookstore-gateway -n bookstore

# Check gateway pod
kubectl get pods -n istio-ingress
kubectl logs -n istio-ingress -l app=istio-ingressgateway

# Verify external IP
kubectl get svc -n istio-ingress

# Test from inside cluster
kubectl run test --rm -it --image=curlimages/curl -- \
  curl -H "Host: bookstore.example.com" http://istio-ingressgateway.istio-ingress
```

### Diagnostic Commands

```bash
# Istio configuration analysis
istioctl analyze -n bookstore

# Proxy status
istioctl proxy-status

# View effective configuration
istioctl proxy-config all deploy/reviews-v1 -n bookstore

# Check routes
istioctl proxy-config routes deploy/reviews-v1 -n bookstore

# Check clusters
istioctl proxy-config clusters deploy/reviews-v1 -n bookstore

# Check listeners
istioctl proxy-config listeners deploy/reviews-v1 -n bookstore

# Describe pod with Istio details
istioctl describe pod reviews-v1-xxx -n bookstore

# Enable debug logging
istioctl proxy-config log deploy/reviews-v1 -n bookstore --level debug

# View metrics
kubectl exec deploy/reviews-v1 -n bookstore -c istio-proxy -- \
  curl localhost:15000/stats/prometheus
```

---

## Summary - Part 3

### What We've Built

✅ Complete istio-gateway chart  
✅ Full bookstore application with:
   - Multiple microservices
   - Canary deployments
   - Traffic management
   - Security policies
   - Monitoring & alerting

✅ Production patterns:
   - Blue-green deployment
   - A/B testing
   - Dark launches
   - Circuit breakers

✅ Multi-environment support

### Complete File List

```
istio-custom-charts/
├── charts/
│   ├── istio-base/          ✅ Part 1
│   ├── istiod/              ✅ Part 2
│   ├── istio-gateway/       ✅ Part 3
│   └── bookstore/           ✅ Part 3
├── scripts/
│   └── install-bookstore.sh ✅
└── docs/
    ├── part1-architecture.md ✅
    ├── part2-control-plane.md ✅
    └── part3-applications.md ✅
```

### Next Steps

1. **Customize for your needs**
   - Add your services
   - Modify traffic rules
   - Adjust resource limits

2. **Integrate with CI/CD**
   - GitHub Actions
   - GitLab CI
   - ArgoCD

3. **Add more features**
   - Rate limiting
   - External services
   - Multi-cluster

4. **Monitor and optimize**
   - Review metrics
   - Tune performance
   - Scale appropriately

---

## Complete Installation Example

```bash
# Clone and setup
git clone https://github.com/your-org/istio-custom-charts
cd istio-custom-charts

# Install everything
./scripts/install-bookstore.sh prod

# Verify
kubectl get all -n bookstore
istioctl proxy-status

# Access application
GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: bookstore.example.com" http://$GATEWAY_IP

# Monitor
kubectl logs -n bookstore -l app=reviews -f
```

---

**🎉 Congratulations!** You now have complete, production-ready Istio Helm charts!
