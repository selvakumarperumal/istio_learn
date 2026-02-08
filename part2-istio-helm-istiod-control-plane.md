# Building Custom Istio Helm Charts from Scratch
## Part 2: Istiod Control Plane Chart

---

## Table of Contents - Part 2
1. [Istiod Overview](#istiod-overview)
2. [Chart Structure](#chart-structure)
3. [Chart Configuration](#chart-configuration)
4. [RBAC Components](#rbac-components)
5. [ConfigMaps](#configmaps)
6. [Deployment](#deployment)
7. [Services](#services)
8. [High Availability](#high-availability)
9. [Webhooks](#webhooks)
10. [Testing & Validation](#testing--validation)

---

## Istiod Overview

### What is Istiod?

Istiod is the unified control plane for Istio, combining Pilot, Citadel, and Galley into a single binary.

```
┌──────────────────────────────────────────────────────────┐
│                    Istiod Components                      │
└──────────────────────────────────────────────────────────┘

╔════════════════════════════════════════════════════════╗
║                      ISTIOD                             ║
╠════════════════════════════════════════════════════════╣
║                                                         ║
║  ┌──────────────────────────────────────────────────┐  ║
║  │               PILOT (Discovery)                   │  ║
║  │  • Service Discovery (watches K8s services)      │  ║
║  │  • Endpoint Discovery (watches pods)             │  ║
║  │  • Configuration Distribution (xDS API)          │  ║
║  │  • Traffic Management (VirtualService, DR)       │  ║
║  └──────────────────────────────────────────────────┘  ║
║                                                         ║
║  ┌──────────────────────────────────────────────────┐  ║
║  │              CITADEL (Security)                   │  ║
║  │  • Certificate Authority (CA)                    │  ║
║  │  • Workload Identity (SPIFFE)                    │  ║
║  │  • Certificate Rotation                          │  ║
║  │  • mTLS Key Distribution                         │  ║
║  └──────────────────────────────────────────────────┘  ║
║                                                         ║
║  ┌──────────────────────────────────────────────────┐  ║
║  │             GALLEY (Configuration)                │  ║
║  │  • Configuration Validation                      │  ║
║  │  • CRD Processing                                │  ║
║  │  • Webhook Management                            │  ║
║  └──────────────────────────────────────────────────┘  ║
║                                                         ║
╚════════════════════════════════════════════════════════╝
                          │
                          │ xDS API (gRPC)
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
    ┌────────┐       ┌────────┐       ┌────────┐
    │Envoy 1 │       │Envoy 2 │       │Envoy 3 │
    └────────┘       └────────┘       └────────┘
```

### Istiod Responsibilities

**1. Service Discovery**
```
Watches Kubernetes:
├── Services
├── Endpoints/EndpointSlices  
├── Pods
└── Nodes

Provides to Envoy:
├── Clusters (upstream services)
├── Endpoints (pod IPs)
└── Load balancing info
```

**2. Configuration Management**
```
Watches Istio CRDs:
├── VirtualService → Route rules
├── DestinationRule → Policies
├── Gateway → Ingress config
├── ServiceEntry → External services
└── PeerAuthentication → mTLS

Converts to Envoy Config:
├── Listeners (LDS)
├── Routes (RDS)
├── Clusters (CDS)
└── Endpoints (EDS)
```

**3. Certificate Management**
```
Acts as CA:
├── Issues workload certificates
├── Rotates certificates automatically
├── Validates certificate requests
└── Manages trust bundles
```

### Control Plane Communication

```
┌─────────────────────────────────────────────────────────┐
│              Istiod Communication Flow                   │
└─────────────────────────────────────────────────────────┘

                    Kubernetes API Server
                            │
                            │ Watch Resources
                            ▼
                    ┌───────────────┐
                    │    Istiod     │
                    │  Port 15010   │ ← Discovery (gRPC)
                    │  Port 15012   │ ← xDS over mTLS  
                    │  Port 15014   │ ← Metrics
                    │  Port 15017   │ ← Webhooks (HTTPS)
                    └───────┬───────┘
                            │
                ┌───────────┼───────────┐
                │           │           │
        Config Push   Certificate   Webhook
         (xDS API)     Signing      Validation
                │           │           │
                ▼           ▼           ▼
            ┌─────────────────────────────┐
            │      Envoy Sidecars         │
            └─────────────────────────────┘
```

---

## Chart Structure

### Directory Layout

```
charts/istiod/
├── Chart.yaml
├── values.yaml
├── values-production.yaml
├── values-ha.yaml
├── README.md
├── .helmignore
├── templates/
│   ├── _helpers.tpl
│   ├── NOTES.txt
│   │
│   ├── rbac/
│   │   ├── serviceaccount.yaml
│   │   ├── serviceaccount-reader.yaml
│   │   ├── clusterrole.yaml
│   │   ├── clusterrole-reader.yaml
│   │   ├── clusterrolebinding.yaml
│   │   ├── clusterrolebinding-reader.yaml
│   │   ├── role.yaml
│   │   └── rolebinding.yaml
│   │
│   ├── config/
│   │   ├── configmap.yaml
│   │   └── configmap-mesh.yaml
│   │
│   ├── workload/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── service-metrics.yaml
│   │
│   ├── scaling/
│   │   ├── horizontalpodautoscaler.yaml
│   │   └── poddisruptionbudget.yaml
│   │
│   ├── webhooks/
│   │   ├── mutatingwebhook.yaml
│   │   └── validatingwebhook.yaml
│   │
│   └── monitoring/
│       ├── servicemonitor.yaml
│       └── prometheusrule.yaml
│
└── tests/
    └── test-connection.yaml
```

---

## Chart Configuration

### Chart.yaml

```yaml
# charts/istiod/Chart.yaml

apiVersion: v2
name: istiod
description: |
  Istio Control Plane (Istiod) - The unified control plane combining
  Pilot (service discovery), Citadel (certificate authority), and
  Galley (configuration validation).
  
  Manages and configures Envoy proxies in the data plane.

type: application
version: 1.0.0
appVersion: "1.21.0"

# Dependencies
dependencies:
  - name: istio-base
    version: "1.0.0"
    repository: "file://../istio-base"
    condition: base.enabled

keywords:
  - istio
  - service-mesh
  - control-plane
  - pilot
  - istiod
  - microservices

home: https://istio.io
sources:
  - https://github.com/istio/istio
  - https://github.com/your-org/istio-custom-charts

maintainers:
  - name: Platform Team
    email: platform@yourcompany.com
  - name: SRE Team
    email: sre@yourcompany.com

icon: https://istio.io/latest/img/istio-blue-logo.svg

annotations:
  category: Infrastructure
  licenses: Apache-2.0
```

### values.yaml (Complete)

```yaml
# charts/istiod/values.yaml

# ============================================================================
# GLOBAL SETTINGS
# ============================================================================
global:
  # Istio namespace
  istioNamespace: istio-system
  
  # Logging configuration
  logging:
    level: "default:info"
  
  # Istio images
  hub: docker.io/istio
  tag: 1.21.0
  imagePullPolicy: IfNotPresent
  imagePullSecrets: []
  
  # Configure trust domain for SPIFFE identities
  # Format: cluster.local
  trustDomain: "cluster.local"
  
  # Proxy configuration (sidecar defaults)
  proxy:
    image: proxyv2
    clusterDomain: "cluster.local"
    
    # Resource defaults for sidecars
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 2000m
        memory: 1024Mi
    
    # Log level for Envoy
    # Options: trace, debug, info, warning, error, critical, off
    logLevel: warning
    
    # Component log levels
    componentLogLevel: "misc:error"
    
    # Enable Envoy access logs
    accessLogFile: ""
    accessLogFormat: ""
    accessLogEncoding: TEXT
    
    # Holdoff time for draining connections during pod shutdown
    terminationDrainDuration: 5s
    
    # Status port for health checks
    statusPort: 15020
    
    # Readiness probe settings
    readinessInitialDelaySeconds: 1
    readinessPeriodSeconds: 2
    readinessFailureThreshold: 30
  
  # Tracing configuration
  tracer:
    zipkin:
      address: ""
    lightstep:
      address: ""
      accessToken: ""
    datadog:
      address: ""
    stackdriver:
      debug: false
      maxNumberOfAttributes: 200
      maxNumberOfAnnotations: 200
      maxNumberOfMessageEvents: 200

# ============================================================================
# PILOT (ISTIOD) CONFIGURATION
# ============================================================================
pilot:
  enabled: true
  
  # Number of replicas
  # Minimum 2 for HA, 3+ for production
  replicaCount: 2
  
  # Image configuration
  image:
    repository: pilot
    tag: ""  # Uses global.tag if not set
    pullPolicy: ""  # Uses global.imagePullPolicy if not set
  
  # ===== RESOURCE LIMITS =====
  resources:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      cpu: 4000m
      memory: 8Gi
  
  # ===== AUTOSCALING =====
  autoscaleEnabled: true
  autoscaleMin: 2
  autoscaleMax: 5
  
  # Target CPU utilization percentage
  cpu:
    targetAverageUtilization: 80
  
  # Target memory utilization (optional)
  memory: {}
  #  targetAverageUtilization: 80
  
  # ===== ROLLING UPDATE STRATEGY =====
  rollingMaxSurge: 100%
  rollingMaxUnavailable: 25%
  
  # ===== POD DISRUPTION BUDGET =====
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
    # maxUnavailable: 1  # Use minAvailable OR maxUnavailable
  
  # ===== ENVIRONMENT VARIABLES =====
  env:
    # Trace sampling percentage (0.0 to 100.0)
    PILOT_TRACE_SAMPLING: "1.0"
    
    # Enable protocol sniffing
    PILOT_ENABLE_PROTOCOL_SNIFFING_FOR_OUTBOUND: "true"
    PILOT_ENABLE_PROTOCOL_SNIFFING_FOR_INBOUND: "true"
    
    # Skip TLS verification for outbound traffic to clusters
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "false"
    
    # Enable analysis for VirtualServices and DestinationRules
    PILOT_ENABLE_ANALYSIS: "false"
    
    # JWT policy
    JWT_POLICY: "third-party-jwt"
    
    # Enable gateway API
    PILOT_ENABLE_GATEWAY_API: "true"
    
    # Status update interval
    PILOT_STATUS_BURST: "500"
    PILOT_STATUS_QPS: "100"
    
    # Push timeout
    PILOT_PUSH_THROTTLE: "100"
    PILOT_DEBOUNCE_AFTER: "100ms"
    PILOT_DEBOUNCE_MAX: "10s"
  
  # ===== KUBERNETES ENVIRONMENT =====
  # Hub to pull control plane images from
  hub: ""  # Uses global.hub if not set
  
  # Tag to use for images
  tag: ""  # Uses global.tag if not set
  
  # ===== POD CONFIGURATION =====
  # Node selector
  nodeSelector: {}
  #  disktype: ssd
  #  cloud.google.com/gke-nodepool: istio-system
  
  # Tolerations
  tolerations: []
  # - key: "key1"
  #   operator: "Equal"
  #   value: "value1"
  #   effect: "NoSchedule"
  
  # Pod annotations
  podAnnotations:
    prometheus.io/port: "15014"
    prometheus.io/scrape: "true"
  
  # Security context for the pod
  podSecurityContext:
    fsGroup: 1337
    runAsUser: 1337
    runAsGroup: 1337
    runAsNonRoot: true
  
  # Security context for containers
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
  
  # Affinity rules (for HA)
  affinity: {}
  # podAntiAffinity:
  #   requiredDuringSchedulingIgnoredDuringExecution:
  #   - labelSelector:
  #       matchLabels:
  #         app: istiod
  #     topologyKey: kubernetes.io/hostname
  
  # ===== PROBES =====
  readinessProbe:
    httpGet:
      path: /ready
      port: 8080
    initialDelaySeconds: 1
    periodSeconds: 3
    timeoutSeconds: 5
    failureThreshold: 3
  
  livenessProbe:
    httpGet:
      path: /healthz
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 30
    timeoutSeconds: 10
    failureThreshold: 3
  
  # ===== PORTS =====
  ports:
  - containerPort: 8080
    protocol: TCP
    name: http-legacy
  - containerPort: 15010
    protocol: TCP
    name: grpc-xds
  - containerPort: 15012
    protocol: TCP
    name: https-dns
  - containerPort: 15017
    protocol: TCP
    name: https-webhook
  - containerPort: 15053
    protocol: TCP
    name: dns
  
  # ===== SERVICE =====
  service:
    type: ClusterIP
    # External traffic policy for LoadBalancer
    # externalTrafficPolicy: Local
    
    # Session affinity
    # sessionAffinity: None
    
    ports:
    - port: 15010
      name: grpc-xds
      protocol: TCP
      targetPort: 15010
    - port: 15012
      name: https-dns
      protocol: TCP
      targetPort: 15012
    - port: 443
      name: https-webhook
      targetPort: 15017
      protocol: TCP
    - port: 15014
      name: http-monitoring
      protocol: TCP
      targetPort: 15014
    - port: 15053
      name: dns
      protocol: TCP
      targetPort: 15053
  
  # ===== VOLUME MOUNTS =====
  volumeMounts:
  - name: config-volume
    mountPath: /etc/istio/config
  - name: istio-token
    mountPath: /var/run/secrets/tokens
    readOnly: true
  - name: local-certs
    mountPath: /var/run/secrets/istio-dns
  - name: cacerts
    mountPath: /etc/cacerts
    readOnly: true
  - name: istio-kubeconfig
    mountPath: /var/run/secrets/remote
    readOnly: true
  
  # ===== VOLUMES =====
  volumes:
  - name: config-volume
    configMap:
      name: istio
  - name: istio-token
    projected:
      sources:
      - serviceAccountToken:
          audience: istio-ca
          expirationSeconds: 43200
          path: istio-token
  - name: local-certs
    emptyDir:
      medium: Memory
  - name: cacerts
    secret:
      secretName: cacerts
      optional: true
  - name: istio-kubeconfig
    secret:
      secretName: istio-kubeconfig
      optional: true
  
  # ===== KEEP ALIVE SETTINGS =====
  keepaliveMaxServerConnectionAge: "30m"

# ============================================================================
# MESH CONFIGURATION
# ============================================================================
meshConfig:
  # Enable Prometheus metrics merge
  enablePrometheusMerge: true
  
  # Access logging
  accessLogFile: /dev/stdout
  accessLogEncoding: JSON
  accessLogFormat: |
    {
      "start_time": "%START_TIME%",
      "method": "%REQ(:METHOD)%",
      "path": "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",
      "protocol": "%PROTOCOL%",
      "response_code": "%RESPONSE_CODE%",
      "response_flags": "%RESPONSE_FLAGS%",
      "bytes_received": "%BYTES_RECEIVED%",
      "bytes_sent": "%BYTES_SENT%",
      "duration": "%DURATION%",
      "upstream_service_time": "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%",
      "x_forwarded_for": "%REQ(X-FORWARDED-FOR)%",
      "user_agent": "%REQ(USER-AGENT)%",
      "request_id": "%REQ(X-REQUEST-ID)%",
      "authority": "%REQ(:AUTHORITY)%",
      "upstream_host": "%UPSTREAM_HOST%",
      "upstream_cluster": "%UPSTREAM_CLUSTER%"
    }
  
  # Default configuration for all proxies
  defaultConfig:
    # Discovery address
    discoveryAddress: istiod.istio-system.svc:15012
    
    # Proxy metadata
    proxyMetadata: {}
    
    # Tracing configuration
    tracing:
      sampling: 1.0
      custom_tags: {}
    
    # Concurrency (0 = auto-detect from CPU)
    concurrency: 2
  
  # Outbound traffic policy
  # ALLOW_ANY: Allow traffic to unknown services (default)
  # REGISTRY_ONLY: Only allow traffic to registered services
  outboundTrafficPolicy:
    mode: ALLOW_ANY
  
  # Locality load balancing
  localityLbSetting:
    enabled: true
    # Distribute load across zones
    # distribute:
    # - from: us-east/zone1/*
    #   to:
    #     "us-east/zone1/*": 80
    #     "us-east/zone2/*": 20
  
  # Default service entry export
  # defaultServiceExportTo:
  # - "*"
  
  # Default virtual service export
  # defaultVirtualServiceExportTo:
  # - "*"
  
  # Default destination rule export
  # defaultDestinationRuleExportTo:
  # - "*"
  
  # DNS refresh rate
  dnsRefreshRate: 300s
  
  # Protocol detection timeout
  protocolDetectionTimeout: 100ms
  
  # Enable auto mTLS when possible
  enableAutoMtls: true
  
  # Trust domain
  trustDomain: cluster.local
  
  # Certificates
  certificates: []
  
  # Service registry
  serviceSettings: []
  
  # Extension providers (for telemetry)
  extensionProviders: []
  # - name: "envoy-json"
  #   envoyFileAccessLog:
  #     path: "/dev/stdout"
  #     logFormat:
  #       labels:
  #         app: productpage

# ============================================================================
# SERVICE ACCOUNT
# ============================================================================
serviceAccount:
  create: true
  name: istiod
  annotations: {}
  # Example: AWS IAM role
  # eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/istiod

# ============================================================================
# WEBHOOKS
# ============================================================================
webhooks:
  # Mutating webhook for sidecar injection
  mutating:
    enabled: true
    # Namespaces to ignore
    namespaceSelector:
      matchExpressions:
      - key: istio-injection
        operator: NotIn
        values:
        - disabled
      - key: kubernetes.io/metadata.name
        operator: NotIn
        values:
        - kube-system
        - kube-public
        - kube-node-lease
    
    # Failure policy
    failurePolicy: Fail
    
    # Timeout seconds
    timeoutSeconds: 10
  
  # Validating webhook for configuration
  validating:
    enabled: true
    failurePolicy: Fail
    timeoutSeconds: 10

# ============================================================================
# TELEMETRY & MONITORING
# ============================================================================
telemetry:
  enabled: true
  
  # Prometheus ServiceMonitor
  prometheus:
    enabled: true
    # Scrape interval
    interval: 15s
    # Scrape timeout  
    scrapeTimeout: 10s

# ============================================================================
# SECURITY
# ============================================================================
security:
  # Enable certificate rotation
  certificateRotation:
    enabled: true
    checkPeriod: 1h
    gracePeriod: 24h
  
  # Self-signed CA or custom CA
  selfSigned:
    enabled: true
    # TTL for self-signed certificates
    ttl: 8760h  # 1 year
  
  # Custom CA secrets (if not self-signed)
  customCA:
    enabled: false
    secretName: cacerts
    # Secret should contain:
    # - ca-cert.pem
    # - ca-key.pem
    # - root-cert.pem
    # - cert-chain.pem

# ============================================================================
# MULTI-CLUSTER
# ============================================================================
multiCluster:
  enabled: false
  clusterName: ""
  
# Network name for multi-network mesh
network: ""

# ============================================================================
# REVISIONS (for canary upgrades)
# ============================================================================
revision: ""
revisionTags: []

# ============================================================================
# EXPERIMENTAL FEATURES
# ============================================================================
experimental:
  # Enable Gateway API
  gatewayAPI: true
```

---

## RBAC Components

### ServiceAccount

#### Kubernetes Manifest

```yaml
# kubernetes/istiod-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: istiod
  namespace: istio-system
  labels:
    app: istiod
    istio: pilot
automountServiceAccountToken: true
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: istio-reader-service-account
  namespace: istio-system
  labels:
    app: istio-reader
    istio: pilot
automountServiceAccountToken: true
```

#### Helm Template

```yaml
# charts/istiod/templates/rbac/serviceaccount.yaml

{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name }}
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: true
{{- end }}
---
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: istio-reader-service-account
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
    app: istio-reader
automountServiceAccountToken: true
{{- end }}
```

### ClusterRole (Complete)

```yaml
# charts/istiod/templates/rbac/clusterrole.yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: istiod-{{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
rules:
  # ===== ISTIO CONFIGURATION =====
  # Read all Istio configuration resources
  - apiGroups:
    - config.istio.io
    - security.istio.io
    - networking.istio.io
    - telemetry.istio.io
    - extensions.istio.io
    resources: ["*"]
    verbs: ["get", "watch", "list"]
  
  # Manage workload entries (for VM support)
  - apiGroups: ["networking.istio.io"]
    resources: ["workloadentries"]
    verbs: ["get", "watch", "list", "update", "patch", "create", "delete"]
  
  - apiGroups: ["networking.istio.io"]
    resources: ["workloadentries/status"]
    verbs: ["get", "watch", "list", "update", "patch", "create", "delete"]
  
  # ===== KUBERNETES CORE RESOURCES =====
  # Service discovery
  - apiGroups: [""]
    resources:
    - endpoints
    - pods
    - services
    - namespaces
    - nodes
    - serviceaccounts
    verbs: ["get", "watch", "list"]
  
  # Endpoint slices (for newer K8s versions)
  - apiGroups: ["discovery.k8s.io"]
    resources: ["endpointslices"]
    verbs: ["get", "list", "watch"]
  
  # ===== GATEWAY API (if enabled) =====
  {{- if .Values.experimental.gatewayAPI }}
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
    - gateways
    - gatewayclasses
    - httproutes
    - tcproutes
    - tlsroutes
    - udproutes
    - referencegrants
    verbs: ["get", "watch", "list", "update", "patch", "create", "delete"]
  
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
    - gateways/status
    - gatewayclasses/status
    - httproutes/status
    - tcproutes/status
    - tlsroutes/status
    - udproutes/status
    verbs: ["get", "update", "patch"]
  {{- end }}
  
  # ===== CERTIFICATE MANAGEMENT =====
  # Read secrets for certificates
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "watch", "list"]
  
  # Certificate signing requests
  - apiGroups: ["certificates.k8s.io"]
    resources:
    - certificatesigningrequests
    - certificatesigningrequests/approval
    - certificatesigningrequests/status
    verbs: ["update", "create", "get", "delete", "watch"]
  
  # Approve CSRs
  - apiGroups: ["certificates.k8s.io"]
    resources: ["signers"]
    resourceNames:
    - kubernetes.io/legacy-unknown
    verbs: ["approve"]
  
  # ===== INGRESS =====
  # Read ingress resources
  - apiGroups: ["networking.k8s.io"]
    resources:
    - ingresses
    - ingressclasses
    verbs: ["get", "list", "watch"]
  
  # Update ingress status
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses/status"]
    verbs: ["*"]
  
  # ===== CONFIGMAPS =====
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
  
  # ===== CUSTOM RESOURCE DEFINITIONS =====
  - apiGroups: ["apiextensions.k8s.io"]
    resources: ["customresourcedefinitions"]
    verbs: ["get", "list", "watch"]
  
  # ===== AUTHORIZATION (for AuthorizationPolicy) =====
  - apiGroups: ["authorization.k8s.io"]
    resources: ["subjectaccessreviews"]
    verbs: ["create"]
  
  # ===== MULTICLUSTER =====
  {{- if .Values.multiCluster.enabled }}
  # Read multicluster secrets
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "watch", "list"]
    # Limit to specific secret names for remote clusters
    # resourceNames: ["istio-remote-secret-cluster-2"]
  {{- end }}
  
  # ===== LEASES (for leader election) =====
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "create", "update"]
```

### ClusterRole Reader

```yaml
# charts/istiod/templates/rbac/clusterrole-reader.yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: istio-reader-{{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
    app: istio-reader
rules:
  # Read-only access for metrics collection, debugging
  - apiGroups:
    - config.istio.io
    - security.istio.io
    - networking.istio.io
    - telemetry.istio.io
    resources: ["*"]
    verbs: ["get", "list", "watch"]
  
  - apiGroups: [""]
    resources:
    - endpoints
    - pods
    - services
    - nodes
    - namespaces
    verbs: ["get", "list", "watch"]
```

### ClusterRoleBinding

```yaml
# charts/istiod/templates/rbac/clusterrolebinding.yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: istiod-{{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: istiod-{{ .Values.global.istioNamespace }}
subjects:
- kind: ServiceAccount
  name: {{ .Values.serviceAccount.name }}
  namespace: {{ .Values.global.istioNamespace }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: istio-reader-{{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
    app: istio-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: istio-reader-{{ .Values.global.istioNamespace }}
subjects:
- kind: ServiceAccount
  name: istio-reader-service-account
  namespace: {{ .Values.global.istioNamespace }}
```

### Role (Namespace-scoped)

```yaml
# charts/istiod/templates/rbac/role.yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: istiod
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
rules:
  # Manage config in istio-system namespace
  - apiGroups: [""]
    resources:
    - configmaps
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  
  # Leader election
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "create", "update"]
  
  # Events
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]
```

### RoleBinding

```yaml
# charts/istiod/templates/rbac/rolebinding.yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: istiod
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: istiod
subjects:
- kind: ServiceAccount
  name: {{ .Values.serviceAccount.name }}
  namespace: {{ .Values.global.istioNamespace }}
```

---

## ConfigMaps

### Main ConfigMap (Istio)

```yaml
# charts/istiod/templates/config/configmap.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: istio
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
data:
  mesh: |-
    {{- if .Values.meshConfig }}
    # Access logging
    {{- if .Values.meshConfig.accessLogFile }}
    accessLogFile: {{ .Values.meshConfig.accessLogFile }}
    {{- end }}
    {{- if .Values.meshConfig.accessLogEncoding }}
    accessLogEncoding: {{ .Values.meshConfig.accessLogEncoding }}
    {{- end }}
    {{- if .Values.meshConfig.accessLogFormat }}
    accessLogFormat: |
{{ .Values.meshConfig.accessLogFormat | indent 6 }}
    {{- end }}
    
    # Default configuration for all proxies
    defaultConfig:
      discoveryAddress: istiod.{{ .Values.global.istioNamespace }}.svc:15012
      {{- if .Values.meshConfig.defaultConfig.proxyMetadata }}
      proxyMetadata:
        {{- toYaml .Values.meshConfig.defaultConfig.proxyMetadata | nindent 8 }}
      {{- end }}
      {{- if .Values.meshConfig.defaultConfig.tracing }}
      tracing:
        {{- toYaml .Values.meshConfig.defaultConfig.tracing | nindent 8 }}
      {{- end }}
      {{- if .Values.meshConfig.defaultConfig.concurrency }}
      concurrency: {{ .Values.meshConfig.defaultConfig.concurrency }}
      {{- end }}
    
    # Enable Prometheus metrics merge
    enablePrometheusMerge: {{ .Values.meshConfig.enablePrometheusMerge }}
    
    # Root namespace for Istio configuration
    rootNamespace: {{ .Values.global.istioNamespace }}
    
    # Trust domain for SPIFFE identities
    trustDomain: {{ .Values.global.trustDomain }}
    
    # Outbound traffic policy
    {{- if .Values.meshConfig.outboundTrafficPolicy }}
    outboundTrafficPolicy:
      mode: {{ .Values.meshConfig.outboundTrafficPolicy.mode }}
    {{- end }}
    
    # Locality load balancing
    {{- if .Values.meshConfig.localityLbSetting }}
    localityLbSetting:
      {{- toYaml .Values.meshConfig.localityLbSetting | nindent 6 }}
    {{- end }}
    
    # DNS refresh rate
    {{- if .Values.meshConfig.dnsRefreshRate }}
    dnsRefreshRate: {{ .Values.meshConfig.dnsRefreshRate }}
    {{- end }}
    
    # Protocol detection timeout
    {{- if .Values.meshConfig.protocolDetectionTimeout }}
    protocolDetectionTimeout: {{ .Values.meshConfig.protocolDetectionTimeout }}
    {{- end }}
    
    # Enable auto mTLS
    {{- if .Values.meshConfig.enableAutoMtls }}
    enableAutoMtls: {{ .Values.meshConfig.enableAutoMtls }}
    {{- end }}
    
    # Extension providers
    {{- if .Values.meshConfig.extensionProviders }}
    extensionProviders:
      {{- toYaml .Values.meshConfig.extensionProviders | nindent 6 }}
    {{- end }}
    {{- end }}
  
  meshNetworks: |-
    # Define networks for multi-network mesh
    {{- if .Values.network }}
    networks:
      {{ .Values.network }}:
        endpoints:
        - fromRegistry: {{ .Values.multiCluster.clusterName | default "Kubernetes" }}
        gateways: []
    {{- else }}
    networks: {}
    {{- end }}
```

---

## Deployment

### Complete Deployment Template

```yaml
# charts/istiod/templates/workload/deployment.yaml

{{- if .Values.pilot.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
    app: istiod
    istio: pilot
    {{- if .Values.revision }}
    istio.io/rev: {{ .Values.revision }}
    {{- end }}
spec:
  replicas: {{ .Values.pilot.replicaCount }}
  
  strategy:
    rollingUpdate:
      maxSurge: {{ .Values.pilot.rollingMaxSurge }}
      maxUnavailable: {{ .Values.pilot.rollingMaxUnavailable }}
    type: RollingUpdate
  
  selector:
    matchLabels:
      {{- include "istiod.selectorLabels" . | nindent 6 }}
  
  template:
    metadata:
      labels:
        {{- include "istiod.selectorLabels" . | nindent 8 }}
        app: istiod
        istio: pilot
        {{- if .Values.revision }}
        istio.io/rev: {{ .Values.revision }}
        {{- end }}
        sidecar.istio.io/inject: "false"
      annotations:
        {{- toYaml .Values.pilot.podAnnotations | nindent 8 }}
        sidecar.istio.io/inject: "false"
    
    spec:
      serviceAccountName: {{ .Values.serviceAccount.name }}
      
      {{- with .Values.pilot.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      
      containers:
      - name: discovery
        image: "{{ .Values.pilot.hub | default .Values.global.hub }}/{{ .Values.pilot.image.repository }}:{{ .Values.pilot.tag | default .Values.global.tag }}"
        imagePullPolicy: {{ .Values.pilot.image.pullPolicy | default .Values.global.imagePullPolicy }}
        
        args:
        - "discovery"
        - --monitoringAddr=:15014
        {{- if .Values.global.logging.level }}
        - --log_output_level={{ .Values.global.logging.level }}
        {{- end }}
        - --domain
        - cluster.local
        - --keepaliveMaxServerConnectionAge
        - {{ .Values.pilot.keepaliveMaxServerConnectionAge }}
        {{- if .Values.meshConfig.trustDomain }}
        - --trust-domain={{ .Values.meshConfig.trustDomain }}
        {{- end }}
        
        ports:
        {{- range .Values.pilot.ports }}
        - containerPort: {{ .containerPort }}
          protocol: {{ .protocol }}
          name: {{ .name }}
        {{- end }}
        
        readinessProbe:
          {{- toYaml .Values.pilot.readinessProbe | nindent 10 }}
        
        livenessProbe:
          {{- toYaml .Values.pilot.livenessProbe | nindent 10 }}
        
        env:
        # ===== REQUIRED ENVIRONMENT VARIABLES =====
        - name: REVISION
          value: {{ .Values.revision | default "default" | quote }}
        
        - name: PILOT_CERT_PROVIDER
          value: istiod
        
        - name: POD_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
        
        - name: SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: spec.serviceAccountName
        
        - name: KUBECONFIG
          value: /var/run/secrets/remote/config
        
        # ===== INJECTION CONFIGURATION =====
        - name: INJECTION_WEBHOOK_CONFIG_NAME
          value: istio-sidecar-injector{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
        
        - name: ISTIOD_ADDR
          value: istiod{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}.{{ .Values.global.istioNamespace }}.svc:15012
        
        - name: VALIDATION_WEBHOOK_CONFIG_NAME
          value: istio-validator{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
        
        # ===== CLUSTER IDENTIFICATION =====
        - name: CLUSTER_ID
          value: {{ .Values.multiCluster.clusterName | default "Kubernetes" }}
        
        {{- if .Values.network }}
        - name: EXTERNAL_ISTIOD
          value: "false"
        {{- end }}
        
        # ===== USER-DEFINED ENVIRONMENT VARIABLES =====
        {{- range $key, $value := .Values.pilot.env }}
        - name: {{ $key }}
          value: {{ $value | quote }}
        {{- end }}
        
        # ===== RESOURCES =====
        resources:
          {{- toYaml .Values.pilot.resources | nindent 10 }}
        
        # ===== SECURITY CONTEXT =====
        {{- with .Values.pilot.securityContext }}
        securityContext:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        
        # ===== VOLUME MOUNTS =====
        volumeMounts:
        {{- range .Values.pilot.volumeMounts }}
        - name: {{ .name }}
          mountPath: {{ .mountPath }}
          {{- if .readOnly }}
          readOnly: {{ .readOnly }}
          {{- end }}
        {{- end }}
      
      # ===== VOLUMES =====
      volumes:
      {{- range .Values.pilot.volumes }}
      - name: {{ .name }}
        {{- if .configMap }}
        configMap:
          name: {{ .configMap.name }}
        {{- else if .projected }}
        projected:
          {{- toYaml .projected | nindent 10 }}
        {{- else if .emptyDir }}
        emptyDir:
          {{- if .emptyDir.medium }}
          medium: {{ .emptyDir.medium }}
          {{- end }}
        {{- else if .secret }}
        secret:
          secretName: {{ .secret.secretName }}
          {{- if .secret.optional }}
          optional: {{ .secret.optional }}
          {{- end }}
        {{- end }}
      {{- end }}
      
      # ===== NODE SELECTOR =====
      {{- with .Values.pilot.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      
      # ===== AFFINITY =====
      {{- with .Values.pilot.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- else }}
      # Default anti-affinity for HA
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  {{- include "istiod.selectorLabels" . | nindent 18 }}
              topologyKey: kubernetes.io/hostname
      {{- end }}
      
      # ===== TOLERATIONS =====
      {{- with .Values.pilot.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      
      # ===== IMAGE PULL SECRETS =====
      {{- with .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
```

---

## Services

### Main Service

```yaml
# charts/istiod/templates/workload/service.yaml

{{- if .Values.pilot.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: istiod{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
    app: istiod
    istio: pilot
    {{- if .Values.revision }}
    istio.io/rev: {{ .Values.revision }}
    {{- end }}
spec:
  type: {{ .Values.pilot.service.type }}
  ports:
  {{- range .Values.pilot.service.ports }}
  - port: {{ .port }}
    name: {{ .name }}
    protocol: {{ .protocol }}
    targetPort: {{ .targetPort }}
  {{- end }}
  selector:
    {{- include "istiod.selectorLabels" . | nindent 4 }}
  {{- if .Values.pilot.service.sessionAffinity }}
  sessionAffinity: {{ .Values.pilot.service.sessionAffinity }}
  {{- end }}
{{- end }}
```

---

## High Availability

### HorizontalPodAutoscaler

```yaml
# charts/istiod/templates/scaling/horizontalpodautoscaler.yaml

{{- if and .Values.pilot.enabled .Values.pilot.autoscaleEnabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: istiod{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
    app: istiod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: istiod{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
  
  minReplicas: {{ .Values.pilot.autoscaleMin }}
  maxReplicas: {{ .Values.pilot.autoscaleMax }}
  
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.pilot.cpu.targetAverageUtilization }}
  {{- if .Values.pilot.memory.targetAverageUtilization }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.pilot.memory.targetAverageUtilization }}
  {{- end }}
  
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 1
        periodSeconds: 60
      selectPolicy: Min
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Max
{{- end }}
```

### PodDisruptionBudget

```yaml
# charts/istiod/templates/scaling/poddisruptionbudget.yaml

{{- if and .Values.pilot.enabled .Values.pilot.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: istiod{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
  namespace: {{ .Values.global.istioNamespace }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
    app: istiod
spec:
  selector:
    matchLabels:
      {{- include "istiod.selectorLabels" . | nindent 6 }}
  {{- if .Values.pilot.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.pilot.podDisruptionBudget.minAvailable }}
  {{- end }}
  {{- if .Values.pilot.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.pilot.podDisruptionBudget.maxUnavailable }}
  {{- end }}
{{- end }}
```

---

## Webhooks

### Mutating Webhook (Sidecar Injection)

```yaml
# charts/istiod/templates/webhooks/mutatingwebhook.yaml

{{- if and .Values.pilot.enabled .Values.webhooks.mutating.enabled }}
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: istio-sidecar-injector{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
    app: sidecar-injector
    {{- if .Values.revision }}
    istio.io/rev: {{ .Values.revision }}
    {{- end }}
webhooks:
- name: rev.namespace.sidecar-injector.istio.io
  clientConfig:
    service:
      name: istiod{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
      namespace: {{ .Values.global.istioNamespace }}
      path: "/inject"
      port: 443
    caBundle: ""  # Filled by istio
  
  sideEffects: None
  rules:
  - operations: ["CREATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  
  failurePolicy: {{ .Values.webhooks.mutating.failurePolicy }}
  matchPolicy: Equivalent
  timeoutSeconds: {{ .Values.webhooks.mutating.timeoutSeconds }}
  
  admissionReviewVersions: ["v1", "v1beta1"]
  
  namespaceSelector:
    {{- toYaml .Values.webhooks.mutating.namespaceSelector | nindent 4 }}
  
  objectSelector:
    matchExpressions:
    - key: sidecar.istio.io/inject
      operator: NotIn
      values:
      - "false"
{{- end }}
```

### Validating Webhook

```yaml
# charts/istiod/templates/webhooks/validatingwebhook.yaml

{{- if and .Values.pilot.enabled .Values.webhooks.validating.enabled }}
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: istio-validator{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
  labels:
    {{- include "istiod.labels" . | nindent 4 }}
    app: istiod
    {{- if .Values.revision }}
    istio.io/rev: {{ .Values.revision }}
    {{- end }}
webhooks:
- name: validation.istio.io
  clientConfig:
    service:
      name: istiod{{- if .Values.revision }}-{{ .Values.revision }}{{- end }}
      namespace: {{ .Values.global.istioNamespace }}
      path: "/validate"
      port: 443
    caBundle: ""  # Filled by istio
  
  sideEffects: None
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups:
    - security.istio.io
    - networking.istio.io
    - telemetry.istio.io
    - extensions.istio.io
    apiVersions: ["*"]
    resources: ["*"]
  
  failurePolicy: {{ .Values.webhooks.validating.failurePolicy }}
  matchPolicy: Equivalent
  timeoutSeconds: {{ .Values.webhooks.validating.timeoutSeconds }}
  
  admissionReviewVersions: ["v1", "v1beta1"]
{{- end }}
```

---

## Testing & Validation

### Installation Steps

```bash
# 1. Ensure istio-base is installed
helm list -n istio-system | grep istio-base

# 2. Lint the chart
helm lint ./charts/istiod

# 3. Template and review
helm template istiod ./charts/istiod > istiod-rendered.yaml
less istiod-rendered.yaml

# 4. Dry run
helm install istiod ./charts/istiod \
  -n istio-system \
  --dry-run \
  --debug

# 5. Install
helm install istiod ./charts/istiod \
  -n istio-system \
  --wait \
  --timeout 10m

# 6. Watch pod status
kubectl get pods -n istio-system -w
```

### Verification

```bash
# Check deployment
kubectl get deployment -n istio-system
kubectl describe deployment istiod -n istio-system

# Check pods
kubectl get pods -n istio-system -l app=istiod
kubectl logs -n istio-system -l app=istiod --tail=100

# Check service
kubectl get svc -n istio-system istiod
kubectl describe svc istiod -n istio-system

# Check HPA
kubectl get hpa -n istio-system
kubectl describe hpa istiod -n istio-system

# Check PDB
kubectl get pdb -n istio-system
kubectl describe pdb istiod -n istio-system

# Check webhooks
kubectl get mutatingwebhookconfigurations | grep istio
kubectl get validatingwebhookconfigurations | grep istio

# Istio proxy status
istioctl proxy-status

# Verify istiod is ready
kubectl exec -n istio-system deploy/istiod -- curl localhost:15014/ready
```

### Test Sidecar Injection

```bash
# Create test namespace with injection enabled
kubectl create namespace test-injection
kubectl label namespace test-injection istio-injection=enabled

# Deploy test pod
kubectl run test -n test-injection --image=nginx

# Verify sidecar was injected
kubectl get pod -n test-injection test -o jsonpath='{.spec.containers[*].name}'
# Should show: test istio-proxy

# Cleanup
kubectl delete namespace test-injection
```

---

## Summary - Part 2

### What We've Built

✅ Complete istiod control plane chart  
✅ Full RBAC configuration  
✅ ConfigMaps for mesh configuration  
✅ Production-ready deployment  
✅ High availability setup  
✅ Webhook configuration  

### Key Components

1. **ServiceAccount** - Identity for istiod
2. **ClusterRole** - Permissions across cluster
3. **ConfigMap** - Mesh configuration
4. **Deployment** - Control plane pods
5. **Service** - Expose istiod
6. **HPA** - Autoscaling
7. **PDB** - Availability during disruptions
8. **Webhooks** - Sidecar injection & validation

### Coming in Part 3

- Gateway chart (Ingress/Egress)
- Complete bookstore application
- Traffic management examples
- Security configurations
- Production deployment patterns
- Multi-environment setup

**Continue to Part 3 for Gateways and Applications!**
