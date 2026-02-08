# Building Custom Istio Helm Charts from Scratch
## Part 1: Architecture, Fundamentals & Base Chart

---

## Table of Contents - Part 1
1. [Introduction](#introduction)
2. [Understanding Istio Architecture](#understanding-istio-architecture)
3. [Why Build Custom Helm Charts](#why-build-custom-helm-charts)
4. [Kubernetes vs Helm Deep Dive](#kubernetes-vs-helm-deep-dive)
5. [Project Structure](#project-structure)
6. [Helm Fundamentals](#helm-fundamentals)
7. [Building Istio Base Chart](#building-istio-base-chart)
8. [Testing and Validation](#testing-and-validation)

---

## Introduction

### What This Guide Covers

This comprehensive three-part guide will teach you how to build production-ready Istio Helm charts from scratch. By the end, you'll have:

- Deep understanding of Istio architecture
- Custom Helm charts for all Istio components
- A complete working application with service mesh features
- Production-ready patterns and best practices

### Series Overview

**Part 1 (This Document):**
- Istio architecture deep dive
- Kubernetes vs Helm comparison
- Helm templating fundamentals
- Building the istio-base chart (CRDs)

**Part 2:**
- Building the istiod chart (Control Plane)
- Complete RBAC configuration
- ConfigMaps and secrets management
- High availability setup

**Part 3:**
- Building the istio-gateway chart
- Complete application example (Bookstore)
- Traffic management patterns
- Security configurations
- Production deployment strategies

### Prerequisites

- Kubernetes cluster (1.27+)
- kubectl configured
- Helm 3.x installed
- Basic understanding of:
  - Kubernetes resources
  - YAML syntax
  - Service mesh concepts

---

## Understanding Istio Architecture

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Istio Service Mesh                         │
└──────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │   Control Plane     │
                    │      (Istiod)       │
                    │                     │
                    │  ┌──────────────┐   │
                    │  │   Pilot      │   │ ← Service Discovery
                    │  │ (Discovery)  │   │   Configuration
                    │  └──────────────┘   │   
                    │  ┌──────────────┐   │
                    │  │   Citadel    │   │ ← Certificate Authority
                    │  │ (Security)   │   │   mTLS Management
                    │  └──────────────┘   │
                    │  ┌──────────────┐   │
                    │  │   Galley     │   │ ← Configuration
                    │  │(Validation)  │   │   Validation
                    │  └──────────────┘   │
                    └──────────┬──────────┘
                               │
                    xDS API (Config Push)
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        │                      │                      │
    ┌───▼────┐            ┌───▼────┐            ┌───▼────┐
    │Gateway │            │ Pod A  │            │ Pod B  │
    │        │            │┌──────┐│            │┌──────┐│
    │┌──────┐│            ││ App  ││            ││ App  ││
    ││Envoy ││            ││ 8080 ││            ││ 8080 ││
    ││Proxy ││            │└──────┘│            │└──────┘│
    │└──────┘│            │┌──────┐│            │┌──────┐│
    │  :80   │            ││Envoy ││◄──mTLS────►││Envoy ││
    │  :443  │            ││15001 ││            ││15001 ││
    └────────┘            │└──────┘│            │└──────┘│
   Ingress/Egress         └────────┘            └────────┘
    Gateway               Data Plane            Data Plane
```

### Component Breakdown

#### 1. **Control Plane (Istiod)**

The unified control plane that manages the service mesh:

```
Istiod Components:
├── Pilot
│   ├── Service Discovery
│   ├── Traffic Management
│   ├── Configuration Distribution
│   └── Envoy Configuration (xDS APIs)
│
├── Citadel
│   ├── Certificate Authority
│   ├── Certificate Rotation
│   ├── Workload Identity
│   └── mTLS Key Distribution
│
└── Galley
    ├── Configuration Validation
    ├── CRD Processing
    └── Configuration Distribution
```

**Responsibilities:**
- Service discovery and endpoint management
- Distributing configuration to Envoy proxies
- Certificate management for mTLS
- Policy enforcement
- Telemetry collection

#### 2. **Data Plane (Envoy Proxies)**

Sidecar proxies deployed alongside each application:

```
Envoy Sidecar:
├── Inbound Traffic (15006)
│   ├── mTLS Termination
│   ├── Authorization
│   └── Forward to App
│
├── Outbound Traffic (15001)
│   ├── mTLS Origination
│   ├── Load Balancing
│   ├── Circuit Breaking
│   └── Retries/Timeouts
│
├── Admin Interface (15000)
│   ├── Configuration
│   ├── Statistics
│   └── Health Checks
│
└── Metrics (15020)
    ├── Prometheus Metrics
    └── Telemetry Data
```

**Responsibilities:**
- Intercept all network traffic
- Apply traffic management rules
- Enforce security policies
- Collect metrics and traces

#### 3. **Gateways**

Special Envoy proxies at the edge:

```
Gateway Types:
├── Ingress Gateway
│   ├── External → Internal Traffic
│   ├── TLS Termination
│   ├── Virtual Host Routing
│   └── Load Balancing
│
└── Egress Gateway
    ├── Internal → External Traffic
    ├── TLS Origination
    ├── Access Control
    └── Monitoring
```

### Traffic Flow Example

```
┌─────────────────────────────────────────────────────────────────┐
│                    Request Flow Diagram                          │
└─────────────────────────────────────────────────────────────────┘

1. External Request
   │
   │  HTTP Request: bookstore.example.com/api/books
   │
   ▼
┌──────────────────┐
│ Ingress Gateway  │  Port 80/443
│  (Envoy Proxy)   │
└────────┬─────────┘
         │
         │ 2. Gateway Resource matches host
         │    Applies VirtualService rules
         ▼
┌──────────────────┐
│ VirtualService   │
│  - Match: /api/books
│  - Rewrite: /books
│  - Route to: books-service
│  - Retry: 3 attempts
│  - Timeout: 10s
└────────┬─────────┘
         │
         │ 3. DestinationRule applied
         │    - Subset selection
         │    - Load balancing
         │    - Circuit breaker
         ▼
┌──────────────────┐
│  Books Service   │
│  ClusterIP       │
└────────┬─────────┘
         │
         │ 4. Kube-proxy routes to Pod
         ▼
┌──────────────────────────┐
│      Books Pod           │
│  ┌────────────────────┐  │
│  │ Envoy Sidecar      │  │ ← 5. Inbound interception
│  │ Port 15006         │  │    - mTLS verification
│  │ ┌────────────────┐ │  │    - AuthZ check
│  │ │ mTLS Terminate │ │  │    - Metrics collection
│  │ │ AuthZ Check    │ │  │
│  │ │ Forward :8080  │ │  │
│  │ └────────────────┘ │  │
│  └──────────┬─────────┘  │
│             │            │
│             ▼            │
│  ┌────────────────────┐  │
│  │  Books App         │  │ ← 6. Application receives
│  │  Port 8080         │  │    plain HTTP request
│  │  (No mTLS aware)   │  │
│  └────────────────────┘  │
└──────────────────────────┘
```

### Configuration Resources Flow

```
┌──────────────────────────────────────────────────────────────┐
│             Istio Configuration Resources                     │
└──────────────────────────────────────────────────────────────┘

User Creates Resources:
│
├── Gateway
│   └── Defines: Ports, protocols, hosts for ingress/egress
│
├── VirtualService
│   └── Defines: Routing rules, retries, timeouts, rewrites
│
├── DestinationRule
│   └── Defines: Load balancing, subsets, circuit breakers
│
├── ServiceEntry
│   └── Defines: External services, mesh expansion
│
├── PeerAuthentication
│   └── Defines: mTLS mode (STRICT, PERMISSIVE, DISABLE)
│
└── AuthorizationPolicy
    └── Defines: Access control (allow/deny rules)

                    ▼
        
        Kubernetes API Server
                    │
                    ▼
        
        Istiod (Pilot) watches for changes
                    │
                    ▼
        
        Converts to Envoy Configuration (xDS)
        ├── Listeners (LDS)
        ├── Routes (RDS)
        ├── Clusters (CDS)
        └── Endpoints (EDS)
                    │
                    ▼
        
        Pushes to all Envoy Proxies via xDS API
                    │
                    ▼
        
        Envoy Proxies apply new configuration
```

---

## Why Build Custom Helm Charts?

### The Problem with Official Charts

While official Istio charts are excellent, they may not fit every organization's needs:

**Limitations:**
1. **Generic Configuration**: One-size-fits-all approach
2. **Limited Customization**: Hard to add org-specific resources
3. **Black Box**: Difficult to understand internals
4. **Update Dependency**: Tied to Istio release cycle
5. **No Special Requirements**: Can't add custom validators, policies

### Benefits of Custom Charts

#### 1. **Complete Control**

```yaml
# Official Chart - Limited options
pilot:
  resources:
    requests:
      cpu: 500m
      memory: 2Gi

# Your Custom Chart - Add anything
pilot:
  resources:
    requests:
      cpu: 500m
      memory: 2Gi
  customConfig:
    enableMyFeature: true
  additionalLabels:
    team: platform
    cost-center: engineering
  extraEnv:
  - name: MY_CUSTOM_VAR
    value: "custom-value"
```

#### 2. **Learning & Understanding**

Building from scratch teaches you:
- How Istio components interact
- What each CRD does
- RBAC requirements
- Security implications
- Performance tuning

#### 3. **Organization Standards**

```yaml
# Add your security policies
global:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1337
    fsGroup: 1337
    seccompProfile:
      type: RuntimeDefault
  
  podSecurityStandards:
    enforce: restricted
  
  networkPolicies:
    enabled: true
    defaultDeny: true
```

#### 4. **Custom Integrations**

```yaml
# Add monitoring, logging, security tools
global:
  monitoring:
    datadog:
      enabled: true
      apiKey: secretRef
  
  logging:
    fluentd:
      enabled: true
      endpoint: logs.company.com
  
  securityScanning:
    trivy:
      enabled: true
```

#### 5. **Version Control & GitOps**

```
your-istio-charts/
├── charts/
│   ├── istio-base/
│   ├── istiod/
│   └── istio-gateway/
├── values/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── .git/
```

---

## Kubernetes vs Helm Deep Dive

### Fundamental Differences

#### **Kubernetes Manifests**

```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
  labels:
    app: myapp
    version: v1
    environment: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: v1
    spec:
      containers:
      - name: myapp
        image: myapp:1.0.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: DATABASE_URL
          value: "postgres://prod-db:5432/myapp"
```

**Problems:**
- ❌ Hardcoded values (replicas, image, env)
- ❌ No reusability between environments
- ❌ Manual find-replace for changes
- ❌ No rollback mechanism
- ❌ Difficult to maintain multiple versions

**Managing Multiple Environments:**

```bash
# You need separate files for each environment
kubernetes/
├── dev/
│   ├── deployment.yaml     # replicas: 1, image: myapp:dev
│   ├── service.yaml
│   └── configmap.yaml
├── staging/
│   ├── deployment.yaml     # replicas: 2, image: myapp:staging
│   ├── service.yaml
│   └── configmap.yaml
└── prod/
    ├── deployment.yaml     # replicas: 3, image: myapp:1.0.0
    ├── service.yaml
    └── configmap.yaml

# Lots of duplication!
```

#### **Helm Charts**

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
    version: {{ .Values.image.tag }}
    environment: {{ .Values.environment }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
        version: {{ .Values.image.tag }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: {{ .Values.service.targetPort }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        env:
        - name: DATABASE_URL
          value: {{ .Values.database.url }}
        {{- range .Values.extraEnv }}
        - name: {{ .name }}
          value: {{ .value }}
        {{- end }}
```

```yaml
# values.yaml (default)
namespace: default
replicaCount: 1
environment: dev

image:
  repository: myapp
  tag: latest
  pullPolicy: IfNotPresent

service:
  targetPort: 8080

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

database:
  url: "postgres://dev-db:5432/myapp"

extraEnv: []
```

```yaml
# values-prod.yaml (overrides)
namespace: production
replicaCount: 3
environment: production

image:
  tag: "1.0.0"

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi

database:
  url: "postgres://prod-db:5432/myapp"

extraEnv:
- name: LOG_LEVEL
  value: "info"
- name: CACHE_ENABLED
  value: "true"
```

**Benefits:**
- ✅ Single template, multiple value files
- ✅ Easy environment management
- ✅ Rollback with `helm rollback`
- ✅ Version tracking
- ✅ Package and distribute

**Installing Different Environments:**

```bash
# Development
helm install myapp ./myapp-chart

# Staging
helm install myapp ./myapp-chart -f values-staging.yaml

# Production
helm install myapp ./myapp-chart -f values-prod.yaml
```

### Detailed Comparison Table

| Feature | Kubernetes YAML | Helm Charts |
|---------|----------------|-------------|
| **Templating** | None | Go templates with {{ }} |
| **Variables** | Hardcoded | values.yaml |
| **Conditionals** | N/A | {{- if }}, {{- else }} |
| **Loops** | Copy/paste | {{- range }} |
| **Functions** | N/A | include, toYaml, quote, etc. |
| **Packaging** | Individual files | Single .tgz archive |
| **Versioning** | Git only | Chart.yaml version + Git |
| **Dependencies** | Manual | Chart.yaml dependencies |
| **Rollback** | Manual kubectl | `helm rollback` |
| **Upgrades** | kubectl apply | `helm upgrade` |
| **Dry Run** | kubectl apply --dry-run | helm template, helm install --dry-run |
| **Validation** | kubectl validate | helm lint |
| **Distribution** | Copy files | Helm repository |
| **Installation** | kubectl apply -f | helm install |
| **Status Tracking** | N/A | helm status, helm history |
| **Testing** | Manual | helm test |

### Real-World Example: Multi-Environment Deployment

#### Kubernetes Approach

```bash
# Directory structure - lots of duplication
environments/
├── dev/
│   ├── namespace.yaml
│   ├── deployment.yaml    # replicas: 1
│   ├── service.yaml
│   ├── configmap.yaml     # LOG_LEVEL: debug
│   └── secrets.yaml       # db: dev-db
├── staging/
│   ├── namespace.yaml
│   ├── deployment.yaml    # replicas: 2
│   ├── service.yaml
│   ├── configmap.yaml     # LOG_LEVEL: info
│   └── secrets.yaml       # db: staging-db
└── prod/
    ├── namespace.yaml
    ├── deployment.yaml    # replicas: 5
    ├── service.yaml
    ├── configmap.yaml     # LOG_LEVEL: warn
    ├── secrets.yaml       # db: prod-db
    └── hpa.yaml           # only in prod

# Deploy dev
kubectl apply -f environments/dev/

# Deploy staging
kubectl apply -f environments/staging/

# Deploy prod
kubectl apply -f environments/prod/

# Update all environments when app changes?
# Edit 3 deployment files manually!
```

#### Helm Approach

```bash
# Directory structure - single template
myapp/
├── Chart.yaml
├── values.yaml              # defaults
├── values-dev.yaml          # dev overrides
├── values-staging.yaml      # staging overrides
├── values-prod.yaml         # prod overrides
└── templates/
    ├── namespace.yaml
    ├── deployment.yaml      # single template
    ├── service.yaml
    ├── configmap.yaml
    ├── secrets.yaml
    └── hpa.yaml            # conditional

# Deploy dev
helm install myapp-dev ./myapp -f values-dev.yaml

# Deploy staging
helm install myapp-staging ./myapp -f values-staging.yaml

# Deploy prod
helm install myapp-prod ./myapp -f values-prod.yaml

# Update all environments?
# Just upgrade the chart version!
helm upgrade myapp-dev ./myapp -f values-dev.yaml
helm upgrade myapp-staging ./myapp -f values-staging.yaml
helm upgrade myapp-prod ./myapp -f values-prod.yaml
```

---

## Project Structure

### Complete Directory Layout

```
istio-custom-charts/
│
├── README.md
├── .gitignore
├── LICENSE
│
├── charts/                          # All chart definitions
│   │
│   ├── istio-base/                  # CRD Chart (Part 1)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values.schema.json       # Optional: JSON schema validation
│   │   ├── README.md
│   │   ├── .helmignore
│   │   ├── templates/
│   │   │   ├── _helpers.tpl
│   │   │   ├── NOTES.txt
│   │   │   ├── namespace.yaml
│   │   │   ├── configmap.yaml
│   │   │   ├── validatingwebhook.yaml
│   │   │   └── crds/
│   │   │       ├── virtualservice.yaml
│   │   │       ├── virtualservice-v1alpha3.yaml
│   │   │       ├── destinationrule.yaml
│   │   │       ├── gateway.yaml
│   │   │       ├── serviceentry.yaml
│   │   │       ├── sidecar.yaml
│   │   │       ├── workloadentry.yaml
│   │   │       ├── workloadgroup.yaml
│   │   │       ├── envoyfilter.yaml
│   │   │       ├── peerauthentication.yaml
│   │   │       ├── requestauthentication.yaml
│   │   │       ├── authorizationpolicy.yaml
│   │   │       ├── telemetry.yaml
│   │   │       └── wasmplugin.yaml
│   │   └── tests/
│   │       └── test-crds.yaml
│   │
│   ├── istiod/                      # Control Plane Chart (Part 2)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-production.yaml
│   │   ├── README.md
│   │   ├── templates/
│   │   │   ├── _helpers.tpl
│   │   │   ├── NOTES.txt
│   │   │   ├── serviceaccount.yaml
│   │   │   ├── clusterrole.yaml
│   │   │   ├── clusterrole-reader.yaml
│   │   │   ├── clusterrolebinding.yaml
│   │   │   ├── role.yaml
│   │   │   ├── rolebinding.yaml
│   │   │   ├── configmap.yaml
│   │   │   ├── configmap-mesh.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── service-metrics.yaml
│   │   │   ├── horizontalpodautoscaler.yaml
│   │   │   ├── poddisruptionbudget.yaml
│   │   │   ├── mutatingwebhook.yaml
│   │   │   ├── validatingwebhook.yaml
│   │   │   ├── telemetry.yaml
│   │   │   └── servicemonitor.yaml
│   │   └── tests/
│   │       └── test-connection.yaml
│   │
│   ├── istio-gateway/               # Gateway Chart (Part 3)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── README.md
│   │   ├── templates/
│   │   │   ├── _helpers.tpl
│   │   │   ├── NOTES.txt
│   │   │   ├── namespace.yaml
│   │   │   ├── serviceaccount.yaml
│   │   │   ├── role.yaml
│   │   │   ├── rolebinding.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── horizontalpodautoscaler.yaml
│   │   │   ├── poddisruptionbudget.yaml
│   │   │   └── networkpolicy.yaml
│   │   └── tests/
│   │
│   └── bookstore-app/              # Example Application (Part 3)
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-prod.yaml
│       ├── README.md
│       ├── templates/
│       │   ├── _helpers.tpl
│       │   ├── NOTES.txt
│       │   ├── namespace.yaml
│       │   ├── deployments/
│       │   │   ├── frontend.yaml
│       │   │   ├── books.yaml
│       │   │   ├── reviews-v1.yaml
│       │   │   ├── reviews-v2.yaml
│       │   │   └── ratings.yaml
│       │   ├── services/
│       │   │   ├── frontend.yaml
│       │   │   ├── books.yaml
│       │   │   ├── reviews.yaml
│       │   │   └── ratings.yaml
│       │   ├── istio/
│       │   │   ├── gateway.yaml
│       │   │   ├── virtualservice.yaml
│       │   │   ├── destinationrule.yaml
│       │   │   └── peerauthentication.yaml
│       │   └── monitoring/
│       │       ├── servicemonitor.yaml
│       │       └── prometheusrule.yaml
│       └── tests/
│
├── scripts/                         # Helper scripts
│   ├── install-all.sh
│   ├── uninstall-all.sh
│   ├── upgrade-istio.sh
│   └── validate-charts.sh
│
├── docs/                            # Documentation
│   ├── installation.md
│   ├── configuration.md
│   ├── troubleshooting.md
│   └── architecture.md
│
├── examples/                        # Example configurations
│   ├── basic-app/
│   ├── canary-deployment/
│   ├── circuit-breaker/
│   ├── mtls-migration/
│   └── multi-cluster/
│
└── ci/                              # CI/CD configurations
    ├── github-actions/
    ├── gitlab-ci/
    └── argocd/
```

### File Purpose Guide

#### Chart.yaml
```yaml
# Defines chart metadata
apiVersion: v2
name: istio-base
description: Istio Base Chart with CRDs
type: application
version: 1.0.0          # Chart version
appVersion: "1.21.0"    # Application version
```

#### values.yaml
```yaml
# Default configuration values
# Users can override these
global:
  istioNamespace: istio-system

pilot:
  replicaCount: 2
```

#### templates/
```
Contains Kubernetes resource templates
Uses Go templating: {{ .Values.x }}
```

#### templates/_helpers.tpl
```
Reusable template functions
Like programming functions for YAML
```

#### templates/NOTES.txt
```
Displayed after installation
Usage instructions for users
```

#### .helmignore
```
Files to ignore when packaging
Like .gitignore for Helm
```

#### tests/
```
Helm test definitions
Automated validation
```

---

## Helm Fundamentals

### 1. Template Syntax

#### Basic Variable Substitution

```yaml
# Simple value
name: {{ .Values.serviceName }}

# With default
name: {{ .Values.serviceName | default "myapp" }}

# With quote
name: {{ .Values.serviceName | quote }}

# Multiple functions
name: {{ .Values.serviceName | upper | quote }}
```

#### Conditionals

```yaml
# If statement
{{- if .Values.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: myapp
{{- end }}

# If-else
{{- if .Values.production }}
  replicas: 5
{{- else }}
  replicas: 1
{{- end }}

# If with comparison
{{- if eq .Values.environment "production" }}
  resources:
    limits:
      cpu: 2000m
{{- end }}

# Multiple conditions
{{- if and .Values.enabled .Values.production }}
  # Only if both are true
{{- end }}

{{- if or .Values.enableA .Values.enableB }}
  # If either is true
{{- end }}
```

#### Loops

```yaml
# Range over list
{{- range .Values.ports }}
- port: {{ .port }}
  name: {{ .name }}
{{- end }}

# Range with index
{{- range $index, $port := .Values.ports }}
- port: {{ $port.port }}
  name: {{ $port.name }}-{{ $index }}
{{- end }}

# Range over map
{{- range $key, $value := .Values.labels }}
{{ $key }}: {{ $value }}
{{- end }}
```

#### Built-in Objects

```yaml
# .Values - values from values.yaml
{{ .Values.replicaCount }}

# .Chart - Chart.yaml contents
{{ .Chart.Name }}
{{ .Chart.Version }}

# .Release - release information
{{ .Release.Name }}
{{ .Release.Namespace }}
{{ .Release.Service }}  # "Helm"

# .Files - access chart files
{{ .Files.Get "config.txt" }}

# .Capabilities - Kubernetes cluster info
{{ .Capabilities.KubeVersion }}
```

### 2. Helper Templates

```yaml
# templates/_helpers.tpl

{{/*
Expand the name of the chart.
*/}}
{{- define "myapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "myapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.chart" . }}
{{ include "myapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "myapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
```

**Using helpers:**

```yaml
# In any template
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
```

### 3. Functions

#### String Functions

```yaml
# upper, lower
{{ .Values.name | upper }}  # "MYAPP"
{{ .Values.name | lower }}  # "myapp"

# quote, squote
{{ .Values.name | quote }}  # "myapp"
{{ .Values.name | squote }} # 'myapp'

# trim, trimSuffix, trimPrefix
{{ .Values.name | trim }}
{{ .Values.name | trimSuffix "-test" }}

# replace
{{ .Values.name | replace "_" "-" }}

# printf
{{ printf "%s-%s" .Release.Name .Chart.Name }}

# default
{{ .Values.name | default "default-name" }}
```

#### Type Conversion

```yaml
# toString, toStrings
{{ .Values.port | toString }}

# toYaml, toJson
{{- toYaml .Values.resources | nindent 10 }}
{{- toJson .Values.config }}

# fromYaml, fromJson
{{- $config := .Values.configString | fromYaml }}
```

#### List Functions

```yaml
# list
{{ list 1 2 3 }}  # [1 2 3]

# append
{{ append .Values.list "newitem" }}

# has
{{- if has "item" .Values.list }}
found!
{{- end }}

# first, last
{{ first .Values.list }}
{{ last .Values.list }}
```

#### Dictionary Functions

```yaml
# dict
{{ dict "key1" "value1" "key2" "value2" }}

# set, unset
{{ $myDict := dict }}
{{ $_ := set $myDict "key" "value" }}
{{ $_ := unset $myDict "key" }}

# hasKey
{{- if hasKey .Values.config "debug" }}
{{- end }}

# keys
{{ keys .Values.labels }}
```

### 4. Flow Control

#### With

```yaml
# Change scope
{{- with .Values.database }}
host: {{ .host }}
port: {{ .port }}
name: {{ .name }}
{{- end }}

# With default
{{- with .Values.database | default dict }}
{{- end }}
```

#### Range

```yaml
# List
{{- range .Values.environments }}
- name: {{ . }}
{{- end }}

# Map
{{- range $key, $value := .Values.labels }}
{{ $key }}: {{ $value | quote }}
{{- end }}

# With index
{{- range $index, $item := .Values.items }}
- {{ $index }}: {{ $item }}
{{- end }}
```

### 5. Whitespace Control

```yaml
# Remove whitespace before
{{- if .Values.enabled }}

# Remove whitespace after
{{ .Values.name -}}

# Remove both
{{- .Values.name -}}

# Example
{{- if .Values.enabled }}
apiVersion: v1  # No extra newline before
{{- end }}
```

### 6. Named Templates (Partials)

```yaml
# Define
{{- define "myapp.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "myapp.fullname" . }}
data:
  key: value
{{- end }}

# Use with include
{{- include "myapp.configmap" . }}

# Use with template (older style)
{{- template "myapp.configmap" . }}

# Include with nindent
labels:
  {{- include "myapp.labels" . | nindent 2 }}
```

---

## Building Istio Base Chart

### Overview

The istio-base chart contains all Custom Resource Definitions (CRDs) that Istio uses. This must be installed first before any other Istio component.

**What it includes:**
- All Istio CRDs (30+ resources)
- Namespace creation
- Base configuration
- Validation webhooks

### Chart.yaml

```yaml
# charts/istio-base/Chart.yaml
apiVersion: v2
name: istio-base
description: |
  Istio Base Chart - Contains all Custom Resource Definitions (CRDs)
  and base configuration for Istio service mesh.
  
  This chart must be installed before istiod and gateways.

type: application
version: 1.0.0
appVersion: "1.21.0"

keywords:
  - istio
  - service-mesh
  - crds
  - networking
  - security

home: https://istio.io
sources:
  - https://github.com/istio/istio
  - https://github.com/your-org/istio-custom-charts

maintainers:
  - name: Platform Team
    email: platform@yourcompany.com

icon: https://istio.io/latest/img/istio-blue-logo.svg

# Annotations for Artifact Hub
annotations:
  category: Infrastructure
  licenses: Apache-2.0
```

### values.yaml

```yaml
# charts/istio-base/values.yaml

# Global settings shared across all Istio components
global:
  # Istio namespace
  istioNamespace: istio-system
  
  # Default log level for Istio components
  # Options: none, error, warn, info, debug
  logLevel: info
  
  # Hub to pull Istio images from
  hub: docker.io/istio
  
  # Default image tag
  tag: 1.21.0
  
  # Image pull policy
  imagePullPolicy: IfNotPresent
  
  # Image pull secrets
  imagePullSecrets: []
  # - name: regcred

# Default revision for multi-revision deployments
# Leave as "default" for standard installations
defaultRevision: "default"

# Base component configuration
base:
  # Enable/disable CRD installation
  enableIstioConfigCRDs: true
  
  # Enable CRD validation
  # This installs a ValidatingWebhookConfiguration
  validation:
    enabled: true

# Control the creation of the istio-system namespace
createNamespace: true

# Additional labels for all resources
commonLabels: {}
#  team: platform
#  managed-by: helm

# Additional annotations for all resources
commonAnnotations: {}
#  company.com/team: platform
```

### templates/_helpers.tpl

```yaml
# charts/istio-base/templates/_helpers.tpl

{{/*
Expand the name of the chart.
*/}}
{{- define "istio-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this.
If release name contains chart name it will be used as a full name.
*/}}
{{- define "istio-base.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "istio-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "istio-base.labels" -}}
helm.sh/chart: {{ include "istio-base.chart" . }}
{{ include "istio-base.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: istio
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "istio-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "istio-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Istio namespace - allow override via values
*/}}
{{- define "istio-base.namespace" -}}
{{- default "istio-system" .Values.global.istioNamespace }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "istio-base.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Revision label - used for canary upgrades
*/}}
{{- define "istio-base.revisionLabel" -}}
{{- if .Values.defaultRevision }}
istio.io/rev: {{ .Values.defaultRevision }}
{{- end }}
{{- end }}
```

### templates/namespace.yaml

```yaml
# charts/istio-base/templates/namespace.yaml

{{- if .Values.createNamespace }}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ include "istio-base.namespace" . }}
  labels:
    {{- include "istio-base.labels" . | nindent 4 }}
    name: {{ include "istio-base.namespace" . }}
    # Disable sidecar injection in istio-system namespace
    istio-injection: disabled
  {{- with .Values.commonAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

### CRD Template: VirtualService

This is a complete, production-ready CRD with full schema validation.

```yaml
# charts/istio-base/templates/crds/virtualservice.yaml

{{- if .Values.base.enableIstioConfigCRDs }}
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: virtualservices.networking.istio.io
  labels:
    {{- include "istio-base.labels" . | nindent 4 }}
    app: istio-pilot
    chart: istio
    heritage: Tiller
    release: istio
  annotations:
    "helm.sh/resource-policy": keep
    {{- include "istio-base.annotations" . | nindent 4 }}
spec:
  group: networking.istio.io
  names:
    kind: VirtualService
    listKind: VirtualServiceList
    plural: virtualservices
    singular: virtualservice
    shortNames:
    - vs
    categories:
    - istio-io
    - networking-istio-io
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
            description: 'Configuration affecting label/content routing, sni routing, etc.'
            type: object
            properties:
              exportTo:
                description: 'A list of namespaces to which this virtual service is exported.'
                type: array
                items:
                  type: string
              gateways:
                description: 'The names of gateways and sidecars that should apply these routes.'
                type: array
                items:
                  type: string
              hosts:
                description: 'The destination hosts to which traffic is being sent.'
                type: array
                items:
                  type: string
              http:
                description: 'An ordered list of route rules for HTTP traffic.'
                type: array
                items:
                  type: object
                  properties:
                    corsPolicy:
                      description: 'Cross-Origin Resource Sharing policy (CORS).'
                      type: object
                      properties:
                        allowCredentials:
                          type: boolean
                        allowHeaders:
                          type: array
                          items:
                            type: string
                        allowMethods:
                          type: array
                          items:
                            type: string
                        allowOrigins:
                          type: array
                          items:
                            type: object
                            oneOf:
                            - required: ["exact"]
                            - required: ["prefix"]
                            - required: ["regex"]
                            properties:
                              exact:
                                type: string
                              prefix:
                                type: string
                              regex:
                                type: string
                        exposeHeaders:
                          type: array
                          items:
                            type: string
                        maxAge:
                          type: string
                    fault:
                      description: 'Fault injection policy to apply on HTTP traffic.'
                      type: object
                      properties:
                        abort:
                          type: object
                          oneOf:
                          - required: ["httpStatus"]
                          - required: ["grpcStatus"]
                          - required: ["http2Error"]
                          properties:
                            grpcStatus:
                              type: string
                            http2Error:
                              type: string
                            httpStatus:
                              type: integer
                            percentage:
                              type: object
                              properties:
                                value:
                                  type: number
                                  format: double
                        delay:
                          type: object
                          oneOf:
                          - required: ["fixedDelay"]
                          - required: ["exponentialDelay"]
                          properties:
                            exponentialDelay:
                              type: string
                            fixedDelay:
                              type: string
                            percent:
                              type: integer
                            percentage:
                              type: object
                              properties:
                                value:
                                  type: number
                                  format: double
                    headers:
                      type: object
                      properties:
                        request:
                          type: object
                          properties:
                            add:
                              type: object
                              additionalProperties:
                                type: string
                            remove:
                              type: array
                              items:
                                type: string
                            set:
                              type: object
                              additionalProperties:
                                type: string
                        response:
                          type: object
                          properties:
                            add:
                              type: object
                              additionalProperties:
                                type: string
                            remove:
                              type: array
                              items:
                                type: string
                            set:
                              type: object
                              additionalProperties:
                                type: string
                    match:
                      type: array
                      items:
                        type: object
                        properties:
                          authority:
                            type: object
                            oneOf:
                            - required: ["exact"]
                            - required: ["prefix"]
                            - required: ["regex"]
                            properties:
                              exact:
                                type: string
                              prefix:
                                type: string
                              regex:
                                type: string
                          gateways:
                            type: array
                            items:
                              type: string
                          headers:
                            type: object
                            additionalProperties:
                              type: object
                              oneOf:
                              - required: ["exact"]
                              - required: ["prefix"]
                              - required: ["regex"]
                              properties:
                                exact:
                                  type: string
                                prefix:
                                  type: string
                                regex:
                                  type: string
                          ignoreUriCase:
                            type: boolean
                          method:
                            type: object
                            oneOf:
                            - required: ["exact"]
                            - required: ["prefix"]
                            - required: ["regex"]
                            properties:
                              exact:
                                type: string
                              prefix:
                                type: string
                              regex:
                                type: string
                          port:
                            type: integer
                          queryParams:
                            type: object
                            additionalProperties:
                              type: object
                              oneOf:
                              - required: ["exact"]
                              - required: ["prefix"]
                              - required: ["regex"]
                              properties:
                                exact:
                                  type: string
                                prefix:
                                  type: string
                                regex:
                                  type: string
                          scheme:
                            type: object
                            oneOf:
                            - required: ["exact"]
                            - required: ["prefix"]
                            - required: ["regex"]
                            properties:
                              exact:
                                type: string
                              prefix:
                                type: string
                              regex:
                                type: string
                          sourceLabels:
                            type: object
                            additionalProperties:
                              type: string
                          sourceNamespace:
                            type: string
                          uri:
                            type: object
                            oneOf:
                            - required: ["exact"]
                            - required: ["prefix"]
                            - required: ["regex"]
                            properties:
                              exact:
                                type: string
                              prefix:
                                type: string
                              regex:
                                type: string
                          withoutHeaders:
                            type: object
                            additionalProperties:
                              type: object
                              oneOf:
                              - required: ["exact"]
                              - required: ["prefix"]
                              - required: ["regex"]
                              properties:
                                exact:
                                  type: string
                                prefix:
                                  type: string
                                regex:
                                  type: string
                    mirror:
                      type: object
                      properties:
                        host:
                          type: string
                        port:
                          type: object
                          properties:
                            number:
                              type: integer
                        subset:
                          type: string
                    mirrorPercent:
                      type: integer
                    mirrorPercentage:
                      type: object
                      properties:
                        value:
                          type: number
                          format: double
                    mirrors:
                      type: array
                      items:
                        type: object
                        properties:
                          destination:
                            type: object
                            properties:
                              host:
                                type: string
                              port:
                                type: object
                                properties:
                                  number:
                                    type: integer
                              subset:
                                type: string
                          percentage:
                            type: object
                            properties:
                              value:
                                type: number
                                format: double
                    name:
                      type: string
                    redirect:
                      type: object
                      oneOf:
                      - required: ["uri"]
                      - required: ["authority"]
                      properties:
                        authority:
                          type: string
                        derivePort:
                          enum:
                          - FROM_PROTOCOL_DEFAULT
                          - FROM_REQUEST_PORT
                          type: string
                        port:
                          type: integer
                        redirectCode:
                          type: integer
                        scheme:
                          type: string
                        uri:
                          type: string
                    retries:
                      type: object
                      properties:
                        attempts:
                          type: integer
                          format: int32
                        perTryTimeout:
                          type: string
                        retryOn:
                          type: string
                        retryRemoteLocalities:
                          type: boolean
                    rewrite:
                      type: object
                      properties:
                        authority:
                          type: string
                        uri:
                          type: string
                    route:
                      type: array
                      items:
                        type: object
                        properties:
                          destination:
                            type: object
                            properties:
                              host:
                                type: string
                              port:
                                type: object
                                properties:
                                  number:
                                    type: integer
                              subset:
                                type: string
                          headers:
                            type: object
                            properties:
                              request:
                                type: object
                                properties:
                                  add:
                                    type: object
                                    additionalProperties:
                                      type: string
                                  remove:
                                    type: array
                                    items:
                                      type: string
                                  set:
                                    type: object
                                    additionalProperties:
                                      type: string
                              response:
                                type: object
                                properties:
                                  add:
                                    type: object
                                    additionalProperties:
                                      type: string
                                  remove:
                                    type: array
                                    items:
                                      type: string
                                  set:
                                    type: object
                                    additionalProperties:
                                      type: string
                          weight:
                            type: integer
                            format: int32
                    timeout:
                      type: string
              tcp:
                description: 'An ordered list of route rules for opaque TCP traffic.'
                type: array
                items:
                  type: object
                  properties:
                    match:
                      type: array
                      items:
                        type: object
                        properties:
                          destinationSubnets:
                            type: array
                            items:
                              type: string
                          gateways:
                            type: array
                            items:
                              type: string
                          port:
                            type: integer
                          sourceLabels:
                            type: object
                            additionalProperties:
                              type: string
                          sourceNamespace:
                            type: string
                          sourceSubnet:
                            type: string
                    route:
                      type: array
                      items:
                        type: object
                        properties:
                          destination:
                            type: object
                            properties:
                              host:
                                type: string
                              port:
                                type: object
                                properties:
                                  number:
                                    type: integer
                              subset:
                                type: string
                          weight:
                            type: integer
                            format: int32
              tls:
                description: 'An ordered list of route rule for non-terminated TLS & HTTPS traffic.'
                type: array
                items:
                  type: object
                  properties:
                    match:
                      type: array
                      items:
                        type: object
                        properties:
                          destinationSubnets:
                            type: array
                            items:
                              type: string
                          gateways:
                            type: array
                            items:
                              type: string
                          port:
                            type: integer
                          sniHosts:
                            type: array
                            items:
                              type: string
                          sourceLabels:
                            type: object
                            additionalProperties:
                              type: string
                          sourceNamespace:
                            type: string
                    route:
                      type: array
                      items:
                        type: object
                        properties:
                          destination:
                            type: object
                            properties:
                              host:
                                type: string
                              port:
                                type: object
                                properties:
                                  number:
                                    type: integer
                              subset:
                                type: string
                          weight:
                            type: integer
                            format: int32
          status:
            type: object
            x-kubernetes-preserve-unknown-fields: true
    subresources:
      status: {}
    additionalPrinterColumns:
    - name: Gateways
      type: string
      description: The names of gateways and sidecars that should apply these routes
      jsonPath: .spec.gateways
    - name: Hosts
      type: string
      description: The destination hosts to which traffic is being sent
      jsonPath: .spec.hosts
    - name: Age
      type: date
      description: 'CreationTimestamp is a timestamp representing the server time when this object was created.'
      jsonPath: .metadata.creationTimestamp
{{- end }}
```

### CRD Template: DestinationRule (Abbreviated)

```yaml
# charts/istio-base/templates/crds/destinationrule.yaml

{{- if .Values.base.enableIstioConfigCRDs }}
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: destinationrules.networking.istio.io
  labels:
    {{- include "istio-base.labels" . | nindent 4 }}
  annotations:
    "helm.sh/resource-policy": keep
spec:
  group: networking.istio.io
  names:
    kind: DestinationRule
    listKind: DestinationRuleList
    plural: destinationrules
    singular: destinationrule
    shortNames:
    - dr
    categories:
    - istio-io
    - networking-istio-io
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
            description: 'Configuration affecting load balancing, outlier detection, etc.'
            type: object
            properties:
              exportTo:
                type: array
                items:
                  type: string
              host:
                description: 'The name of a service from the service registry.'
                type: string
              subsets:
                type: array
                items:
                  type: object
                  properties:
                    labels:
                      type: object
                      additionalProperties:
                        type: string
                    name:
                      type: string
                    trafficPolicy:
                      type: object
                      # Full traffic policy schema here...
              trafficPolicy:
                type: object
                properties:
                  connectionPool:
                    type: object
                    properties:
                      http:
                        type: object
                        properties:
                          h2UpgradePolicy:
                            enum:
                            - DEFAULT
                            - DO_NOT_UPGRADE
                            - UPGRADE
                            type: string
                          http1MaxPendingRequests:
                            type: integer
                          http2MaxRequests:
                            type: integer
                          idleTimeout:
                            type: string
                          maxRequestsPerConnection:
                            type: integer
                          maxRetries:
                            type: integer
                          useClientProtocol:
                            type: boolean
                      tcp:
                        type: object
                        properties:
                          connectTimeout:
                            type: string
                          maxConnections:
                            type: integer
                          tcpKeepalive:
                            type: object
                            properties:
                              interval:
                                type: string
                              probes:
                                type: integer
                              time:
                                type: string
                  loadBalancer:
                    type: object
                    # Load balancer configuration...
                  outlierDetection:
                    type: object
                    properties:
                      baseEjectionTime:
                        type: string
                      consecutive5xxErrors:
                        type: integer
                      consecutiveErrors:
                        type: integer
                      consecutiveGatewayErrors:
                        type: integer
                      consecutiveLocalOriginFailures:
                        type: integer
                      interval:
                        type: string
                      maxEjectionPercent:
                        type: integer
                      minHealthPercent:
                        type: integer
                      splitExternalLocalOriginErrors:
                        type: boolean
                  tls:
                    type: object
                    properties:
                      caCertificates:
                        type: string
                      clientCertificate:
                        type: string
                      mode:
                        enum:
                        - DISABLE
                        - SIMPLE
                        - MUTUAL
                        - ISTIO_MUTUAL
                        type: string
                      privateKey:
                        type: string
                      sni:
                        type: string
                      subjectAltNames:
                        type: array
                        items:
                          type: string
    additionalPrinterColumns:
    - name: Host
      type: string
      description: The name of a service from the service registry
      jsonPath: .spec.host
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
{{- end }}
```

### Additional CRDs (Summary)

You'll need to create similar CRD files for:

1. **gateway.yaml** - Ingress/Egress gateway configuration
2. **serviceentry.yaml** - External service registration
3. **sidecar.yaml** - Sidecar configuration
4. **workloadentry.yaml** - VM workload registration
5. **workloadgroup.yaml** - VM workload groups
6. **envoyfilter.yaml** - Low-level Envoy configuration
7. **peerauthentication.yaml** - mTLS configuration
8. **requestauthentication.yaml** - JWT validation
9. **authorizationpolicy.yaml** - Access control
10. **telemetry.yaml** - Observability configuration

Each follows the same structure as shown above.

### templates/NOTES.txt

```yaml
# charts/istio-base/templates/NOTES.txt

╔══════════════════════════════════════════════════════════════╗
║          Istio Base Chart Successfully Installed!             ║
╚══════════════════════════════════════════════════════════════╝

✅ Custom Resource Definitions (CRDs) have been installed

📋 Installed CRDs:
{{- if .Values.base.enableIstioConfigCRDs }}
   • VirtualService
   • DestinationRule
   • Gateway
   • ServiceEntry
   • Sidecar
   • WorkloadEntry
   • WorkloadGroup
   • EnvoyFilter
   • PeerAuthentication
   • RequestAuthentication
   • AuthorizationPolicy
   • Telemetry
{{- end }}

🔍 Verify Installation:
   kubectl get crds | grep istio.io
   
📦 Namespace Created:
   {{ include "istio-base.namespace" . }}

⏭️  Next Steps:
   1. Install Istio Control Plane (istiod):
      helm install istiod ./istiod -n {{ include "istio-base.namespace" . }}
   
   2. Install Istio Ingress Gateway:
      helm install istio-ingressgateway ./istio-gateway
   
   3. Enable sidecar injection in your namespace:
      kubectl label namespace <your-namespace> istio-injection=enabled

📖 Documentation:
   https://istio.io/latest/docs/

🐛 Troubleshooting:
   kubectl get crds | grep istio
   kubectl describe crd virtualservices.networking.istio.io

{{ if .Release.IsUpgrade }}
⚠️  UPGRADE NOTICE:
   This is an upgrade. CRDs are not automatically upgraded.
   Review https://helm.sh/docs/chart_best_practices/custom_resource_definitions/
{{ end }}
```

---

## Testing and Validation

### 1. Template Validation

```bash
# Test template rendering without installing
helm template istio-base ./charts/istio-base

# Test with custom values
helm template istio-base ./charts/istio-base \
  --set global.istioNamespace=custom-istio

# Save rendered output
helm template istio-base ./charts/istio-base > rendered.yaml
```

### 2. Linting

```bash
# Lint the chart
helm lint ./charts/istio-base

# Expected output:
# ==> Linting ./charts/istio-base
# [INFO] Chart.yaml: icon is recommended
# 1 chart(s) linted, 0 chart(s) failed
```

### 3. Dry Run Installation

```bash
# Simulate installation
helm install istio-base ./charts/istio-base \
  -n istio-system \
  --create-namespace \
  --dry-run \
  --debug

# This shows what would be installed without actually installing
```

### 4. Actual Installation

```bash
# Install the chart
helm install istio-base ./charts/istio-base \
  -n istio-system \
  --create-namespace

# Output:
# NAME: istio-base
# LAST DEPLOYED: Mon Feb 08 10:00:00 2026
# NAMESPACE: istio-system
# STATUS: deployed
# REVISION: 1
# NOTES:
# [Your NOTES.txt content]
```

### 5. Verification Commands

```bash
# List installed charts
helm list -n istio-system

# Get chart status
helm status istio-base -n istio-system

# Get chart values
helm get values istio-base -n istio-system

# Get all resources
helm get manifest istio-base -n istio-system

# Verify CRDs
kubectl get crds | grep istio.io

# Expected:
# authorizationpolicies.security.istio.io
# destinationrules.networking.istio.io
# envoyfilters.networking.istio.io
# gateways.networking.istio.io
# peerauthentications.security.istio.io
# requestauthentications.security.istio.io
# serviceentries.networking.istio.io
# sidecars.networking.istio.io
# telemetries.telemetry.istio.io
# virtualservices.networking.istio.io
# workloadentries.networking.istio.io
# workloadgroups.networking.istio.io

# Check namespace
kubectl get namespace istio-system

# Describe a CRD
kubectl describe crd virtualservices.networking.istio.io
```

### 6. Test CRD Usage

```yaml
# test-virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: test-vs
  namespace: default
spec:
  hosts:
  - example.com
  http:
  - route:
    - destination:
        host: test-service
```

```bash
# This should work after base chart installation
kubectl apply -f test-virtualservice.yaml

# Verify
kubectl get virtualservice test-vs -n default

# Cleanup
kubectl delete virtualservice test-vs -n default
```

### 7. Upgrade Testing

```bash
# Make changes to values or templates
# Then upgrade
helm upgrade istio-base ./charts/istio-base \
  -n istio-system

# Check history
helm history istio-base -n istio-system

# Rollback if needed
helm rollback istio-base 1 -n istio-system
```

---

## Summary - Part 1

### What We've Built

✅ Complete understanding of Istio architecture  
✅ Kubernetes vs Helm comparison  
✅ Helm templating fundamentals  
✅ Complete istio-base chart with:
   - All CRDs
   - Proper labeling and annotations
   - Flexible configuration
   - Production-ready

### Key Takeaways

1. **CRDs must be installed first** - They define the API resources
2. **Helm provides powerful templating** - Reuse across environments
3. **Proper structure matters** - Helpers, labels, annotations
4. **Validation is crucial** - Lint, dry-run, test

### Coming in Part 2

- Building the istiod chart (Control Plane)
- Complete RBAC configuration
- ServiceAccount, ClusterRole, ClusterRoleBinding
- Deployment with HA
- ConfigMaps and mesh configuration
- HorizontalPodAutoscaler
- PodDisruptionBudget
- Webhook configuration

### File Checklist

```
charts/istio-base/
├── Chart.yaml ✅
├── values.yaml ✅
├── templates/
│   ├── _helpers.tpl ✅
│   ├── NOTES.txt ✅
│   ├── namespace.yaml ✅
│   └── crds/
│       ├── virtualservice.yaml ✅
│       ├── destinationrule.yaml ✅
│       └── [10 more CRDs to create...]
```

---

**Continue to Part 2 for the Istiod (Control Plane) Chart!**
