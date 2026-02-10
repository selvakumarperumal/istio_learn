# Request Routing — Diagrams

## Overall Architecture

```mermaid
graph TB
    Client["🌐 Client (curl)"]
    GW["🚪 Istio Gateway<br/>Port 80"]
    VS["📋 VirtualService<br/>Header-based rules"]
    DR["🏷️ DestinationRule<br/>Subset definitions"]
    SVC["🔗 Kubernetes Service<br/>reviews-svc"]
    V1["📦 Pod: reviews-v1<br/>version: v1"]
    V2["📦 Pod: reviews-v2<br/>version: v2"]
    V3["📦 Pod: reviews-v3<br/>version: v3"]

    Client -->|"HTTP request"| GW
    GW -->|"Host match"| VS
    VS -->|"uses subsets"| DR
    DR -->|"label selector"| SVC
    SVC --> V1
    SVC --> V2
    SVC --> V3

    style GW fill:#4CAF50,color:#fff
    style VS fill:#2196F3,color:#fff
    style DR fill:#FF9800,color:#fff
    style V1 fill:#9C27B0,color:#fff
    style V2 fill:#9C27B0,color:#fff
    style V3 fill:#9C27B0,color:#fff
```

## Request Flow — Header-Based Routing Decision

```mermaid
flowchart TD
    REQ["📨 Incoming Request"]
    H1{"Header<br/>x-user-type = beta?"}
    H2{"Header<br/>x-user-type = internal?"}
    DEFAULT["No match<br/>(default rule)"]
    R1["✅ Route to subset: v2<br/>(beta version)"]
    R2["✅ Route to subset: v3<br/>(internal version)"]
    R3["✅ Route to subset: v1<br/>(stable version)"]

    REQ --> H1
    H1 -->|"YES"| R1
    H1 -->|"NO"| H2
    H2 -->|"YES"| R2
    H2 -->|"NO"| DEFAULT
    DEFAULT --> R3

    style REQ fill:#607D8B,color:#fff
    style R1 fill:#4CAF50,color:#fff
    style R2 fill:#FF9800,color:#fff
    style R3 fill:#2196F3,color:#fff
```

## Label Matching — How Subsets Find Pods

```mermaid
graph LR
    subgraph DestinationRule
        S1["Subset: v1<br/>version=v1"]
        S2["Subset: v2<br/>version=v2"]
        S3["Subset: v3<br/>version=v3"]
    end

    subgraph Kubernetes Service
        SVC["reviews-svc<br/>selector: app=reviews"]
    end

    subgraph Pods
        P1["Pod<br/>app=reviews<br/>version=v1"]
        P2["Pod<br/>app=reviews<br/>version=v2"]
        P3["Pod<br/>app=reviews<br/>version=v3"]
    end

    SVC -.->|"selects all"| P1
    SVC -.->|"selects all"| P2
    SVC -.->|"selects all"| P3
    S1 -->|"filters"| P1
    S2 -->|"filters"| P2
    S3 -->|"filters"| P3

    style S1 fill:#4CAF50,color:#fff
    style S2 fill:#FF9800,color:#fff
    style S3 fill:#9C27B0,color:#fff
    style P1 fill:#4CAF50,color:#fff
    style P2 fill:#FF9800,color:#fff
    style P3 fill:#9C27B0,color:#fff
```

## VirtualService Rule Evaluation Order

```mermaid
sequenceDiagram
    participant C as Client
    participant E as Envoy Proxy
    participant V1 as reviews-v1
    participant V2 as reviews-v2
    participant V3 as reviews-v3

    Note over C,V3: Scenario 1: Beta user
    C->>E: GET /reviews (x-user-type: beta)
    E->>E: Rule 1: header=beta? YES ✅
    E->>V2: Forward to subset v2
    V2-->>C: Response from v2

    Note over C,V3: Scenario 2: Internal user
    C->>E: GET /reviews (x-user-type: internal)
    E->>E: Rule 1: header=beta? NO
    E->>E: Rule 2: header=internal? YES ✅
    E->>V3: Forward to subset v3
    V3-->>C: Response from v3

    Note over C,V3: Scenario 3: Regular user (no header)
    C->>E: GET /reviews (no header)
    E->>E: Rule 1: header=beta? NO
    E->>E: Rule 2: header=internal? NO
    E->>E: Rule 3: default (no match) ✅
    E->>V1: Forward to subset v1
    V1-->>C: Response from v1
```

## Gateway — External Traffic Entry Point

```mermaid
graph TB
    INTERNET["🌍 Internet / External Client"]

    subgraph "Istio Ingress Gateway Pod"
        LISTENER["👂 Listener<br/>Port 80 (HTTP)<br/>Port 443 (HTTPS)"]
        HOST_MATCH{"Host header<br/>match?"}
        ENVOY_GW["⚡ Envoy Proxy<br/>(istio-ingressgateway)"]
    end

    subgraph "Gateway Resource (YAML)"
        GW_SPEC["spec.selector:<br/>  istio: ingressgateway<br/>spec.servers:<br/>  - port: 80<br/>    hosts: reviews.example.com"]
    end

    subgraph "VirtualService"
        VS["gateways:<br/>  - reviews-gateway<br/>hosts:<br/>  - reviews.example.com"]
    end

    INTERNET -->|"HTTP request"| LISTENER
    LISTENER --> HOST_MATCH
    HOST_MATCH -->|"reviews.example.com ✅"| ENVOY_GW
    HOST_MATCH -->|"unknown.com ❌"| DROP["404 Not Found"]
    ENVOY_GW -->|"route rules"| VS
    GW_SPEC -.->|"configures"| LISTENER

    style LISTENER fill:#4CAF50,color:#fff
    style ENVOY_GW fill:#2196F3,color:#fff
    style DROP fill:#f44336,color:#fff
```

## Full Ingress Traffic Path (End-to-End)

```mermaid
sequenceDiagram
    participant EXT as External Client
    participant LB as LoadBalancer / NodePort
    participant GW as Istio Gateway Pod<br/>(Envoy)
    participant VS as VirtualService Rules
    participant DR as DestinationRule
    participant SVC as K8s Service
    participant POD as App Pod (Envoy + App)

    EXT->>LB: curl -H "Host: reviews.example.com"
    LB->>GW: Forward to port 80
    GW->>GW: Gateway: Match host "reviews.example.com" ✅
    GW->>VS: Apply VirtualService routing rules
    VS->>VS: Check headers → select subset
    VS->>DR: Resolve subset → pod labels
    DR->>SVC: Find pods with matching labels
    SVC->>POD: Route to selected pod
    POD-->>EXT: HTTP Response
```

## Gateway YAML ↔ VirtualService Binding

```mermaid
graph LR
    subgraph "gateway.yaml"
        GW["Gateway: reviews-gateway<br/>selector: istio: ingressgateway<br/>servers:<br/>  port: 80, host: *.example.com"]
    end

    subgraph "virtualservice.yaml"
        VS["VirtualService<br/>gateways: [reviews-gateway]<br/>hosts: [reviews.example.com]"]
    end

    subgraph "Istio Ingress Gateway Pod"
        ENVOY["Envoy Proxy<br/>label: istio=ingressgateway"]
    end

    GW -->|"selector matches<br/>pod label"| ENVOY
    VS -->|"gateways field<br/>references name"| GW
    ENVOY -->|"applies VS<br/>routing rules"| VS

    style GW fill:#4CAF50,color:#fff
    style VS fill:#2196F3,color:#fff
    style ENVOY fill:#FF9800,color:#fff
```
