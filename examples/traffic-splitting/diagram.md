# Traffic Splitting (Canary) — Diagrams

## Overall Architecture

```mermaid
graph TB
    Client["🌐 Client"]
    GW["🚪 Istio Gateway"]
    EP["⚡ Envoy Proxy<br/>Weight-based routing"]
    V1["📦 v1 (Stable)<br/>weight: 80"]
    V2["📦 v2 (Canary)<br/>weight: 20"]

    Client --> GW --> EP
    EP -->|"80% of traffic"| V1
    EP -->|"20% of traffic"| V2

    style V1 fill:#4CAF50,color:#fff
    style V2 fill:#FF9800,color:#fff
    style EP fill:#2196F3,color:#fff
```

## Gradual Rollout Strategy

```mermaid
graph LR
    subgraph "Day 1"
        D1V1["v1: 95%"]
        D1V2["v2: 5%"]
    end
    subgraph "Day 2"
        D2V1["v1: 80%"]
        D2V2["v2: 20%"]
    end
    subgraph "Day 3"
        D3V1["v1: 50%"]
        D3V2["v2: 50%"]
    end
    subgraph "Day 4"
        D4V1["v1: 0%"]
        D4V2["v2: 100%"]
    end

    D1V2 --> D2V2 --> D3V2 --> D4V2

    style D1V2 fill:#FF9800,color:#fff
    style D2V2 fill:#FF9800,color:#fff
    style D3V2 fill:#FF9800,color:#fff
    style D4V2 fill:#4CAF50,color:#fff
```

## Weight-Based Routing Decision

```mermaid
flowchart TD
    REQ["📨 Request arrives"]
    DICE{"🎲 Random number<br/>0-99"}
    V1["Route to v1 (stable)<br/>✅ Proven version"]
    V2["Route to v2 (canary)<br/>🧪 New version"]

    REQ --> DICE
    DICE -->|"0-79 (80%)"| V1
    DICE -->|"80-99 (20%)"| V2

    style V1 fill:#4CAF50,color:#fff
    style V2 fill:#FF9800,color:#fff
```

## Traffic Distribution Over 20 Requests

```mermaid
pie title "80/20 Split: 20 requests"
    "v1 (stable): ~16 requests" : 80
    "v2 (canary): ~4 requests" : 20
```

## Canary Deploy — Sequence

```mermaid
sequenceDiagram
    participant OPS as DevOps
    participant VS as VirtualService
    participant V1 as v1 (stable)
    participant V2 as v2 (canary)
    participant MON as Monitoring

    OPS->>VS: Deploy v2, set weight: 5%
    Note over V1: 95% of traffic
    Note over V2: 5% of traffic

    MON->>MON: Check error rate, latency
    MON-->>OPS: All metrics OK ✅

    OPS->>VS: Increase weight: 20%
    Note over V1: 80% of traffic
    Note over V2: 20% of traffic

    MON->>MON: Check metrics
    MON-->>OPS: All metrics OK ✅

    OPS->>VS: Increase weight: 50%
    MON->>MON: Check metrics
    MON-->>OPS: All metrics OK ✅

    OPS->>VS: Full rollout: 100%
    Note over V1: 0% (scale down)
    Note over V2: 100% (new stable)
```

## Rollback Scenario

```mermaid
sequenceDiagram
    participant OPS as DevOps
    participant VS as VirtualService
    participant V1 as v1 (stable)
    participant V2 as v2 (canary)
    participant MON as Monitoring

    OPS->>VS: Set weight: 20% to v2
    Note over V2: 20% of traffic

    MON->>MON: Check metrics
    MON-->>OPS: ⚠️ Error rate spike on v2!

    OPS->>VS: ROLLBACK: weight 100% to v1
    Note over V1: 100% of traffic ✅
    Note over V2: 0% (investigate offline)

    Note over OPS: Fix v2, try again later
```

## Traffic Splitting vs Request Routing

```mermaid
graph TB
    subgraph "Traffic Splitting"
        TS_REQ["Any request"]
        TS_DICE["🎲 Random %"]
        TS_V1["v1 (80%)"]
        TS_V2["v2 (20%)"]
        TS_REQ --> TS_DICE
        TS_DICE --> TS_V1
        TS_DICE --> TS_V2
    end

    subgraph "Request Routing"
        RR_REQ["Request + headers"]
        RR_CHECK["📋 Header match"]
        RR_V1["v1 (default)"]
        RR_V2["v2 (beta header)"]
        RR_REQ --> RR_CHECK
        RR_CHECK -->|"x-user-type: beta"| RR_V2
        RR_CHECK -->|"no header"| RR_V1
    end

    style TS_V1 fill:#4CAF50,color:#fff
    style TS_V2 fill:#FF9800,color:#fff
    style RR_V1 fill:#4CAF50,color:#fff
    style RR_V2 fill:#2196F3,color:#fff
```

## Gateway + Full Resource Chain

```mermaid
graph TB
    EXT["🌍 External Client"]

    subgraph "Istio Ingress Gateway"
        GW["👂 Gateway Envoy<br/>Port 80<br/>Host: reviews.example.com"]
    end

    subgraph "VirtualService (Weights live HERE)"
        VS["📋 route:<br/>  - dest: v1, weight: 80<br/>  - dest: v2, weight: 20"]
    end

    subgraph "DestinationRule"
        DR["🏷️ Subsets:<br/>v1: version=v1<br/>v2: version=v2"]
    end

    subgraph "Namespace"
        V1["📦 v1 Pods (3 replicas)<br/>Gets 80% of traffic"]
        V2["📦 v2 Pods (1 replica)<br/>Gets 20% of traffic"]
    end

    EXT --> GW
    GW --> VS
    VS --> DR
    DR -->|"80%"| V1
    DR -->|"20%"| V2

    style GW fill:#4CAF50,color:#fff
    style VS fill:#2196F3,color:#fff
    style V1 fill:#4CAF50,color:#fff
    style V2 fill:#FF9800,color:#fff
```

## End-to-End with Gateway

```mermaid
sequenceDiagram
    participant EXT as External Client
    participant LB as LoadBalancer
    participant GW as Gateway Envoy
    participant V1 as v1 Pod (stable)
    participant V2 as v2 Pod (canary)

    EXT->>LB: GET /reviews (Host: reviews.example.com)
    LB->>GW: Forward to port 80
    GW->>GW: Gateway: host match ✅
    GW->>GW: VirtualService: roll dice 🎲

    alt 80% chance
        GW->>V1: Route to v1 (stable)
        V1-->>EXT: 200 OK (v1 response)
    else 20% chance
        GW->>V2: Route to v2 (canary)
        V2-->>EXT: 200 OK (v2 response)
    end
```

