# Retries & Timeouts — Diagrams

## Overall Architecture

```mermaid
graph TB
    Client["🌐 Client"]
    EP["⚡ Envoy Proxy<br/>Retry + Timeout Logic"]
    SVC["📦 Product Service"]

    Client -->|"Request"| EP
    EP -->|"Attempt 1"| SVC
    EP -->|"Attempt 2 (retry)"| SVC
    EP -->|"Attempt 3 (retry)"| SVC
    SVC -->|"Response"| EP
    EP -->|"Final response"| Client

    style EP fill:#FF9800,color:#fff
    style SVC fill:#2196F3,color:#fff
```

## Timeout Budget Diagram

```mermaid
gantt
    title Timeout Budget: 5s overall, 2s per-try, 3 attempts
    dateFormat X
    axisFormat %s

    section Attempt 1
    Try 1 (timeout at 2s)    :crit, t1, 0, 2

    section Attempt 2
    Try 2 (timeout at 2s)    :crit, t2, 2, 4

    section Attempt 3
    Try 3 (budget runs out at 5s) :crit, t3, 4, 5

    section Overall
    Overall Timeout (5s)      :active, ot, 0, 5
```

## Retry Decision Flow

```mermaid
flowchart TD
    REQ["📨 Request Arrives"]
    SEND["Send to upstream service"]
    RESP{"Response received?"}
    CODE{"Status code?"}
    RETRY{"retryOn match?<br/>5xx, reset, connect-failure"}
    BUDGET{"Overall timeout<br/>remaining?"}
    ATTEMPTS{"Retry attempts<br/>remaining?"}
    OK["✅ Return response to client"]
    FAIL["❌ Return last error to client"]
    WAIT["⏳ Backoff delay<br/>25ms → 50ms → 100ms"]

    REQ --> SEND
    SEND --> RESP
    RESP -->|"Timeout (per-try)"| RETRY
    RESP -->|"Got response"| CODE
    CODE -->|"200 OK"| OK
    CODE -->|"500/502/503"| RETRY
    CODE -->|"400/401/404"| OK
    RETRY -->|"Matches retryOn"| BUDGET
    RETRY -->|"Not retryable"| OK
    BUDGET -->|"Time left"| ATTEMPTS
    BUDGET -->|"No time left"| FAIL
    ATTEMPTS -->|"Attempts left"| WAIT
    ATTEMPTS -->|"No attempts left"| FAIL
    WAIT --> SEND

    style OK fill:#4CAF50,color:#fff
    style FAIL fill:#f44336,color:#fff
    style WAIT fill:#FF9800,color:#fff
```

## Scenario: Retry Succeeds on 2nd Attempt

```mermaid
sequenceDiagram
    participant C as Client
    participant E as Envoy Proxy
    participant S as Product Service

    C->>E: GET /products
    Note over E: Overall timeout: 5s<br/>Per-try: 2s<br/>Attempts: 3

    E->>S: Attempt 1
    S-->>E: 503 Service Unavailable ❌
    Note over E: 503 matches retryOn<br/>Budget: 4.9s left

    E->>E: Backoff: 25ms
    E->>S: Attempt 2
    S-->>E: 200 OK ✅

    E-->>C: 200 OK (client never saw the 503!)
    Note over C: Total time: ~150ms<br/>Transparent recovery ✅
```

## Scenario: All Retries Fail

```mermaid
sequenceDiagram
    participant C as Client
    participant E as Envoy Proxy
    participant S as Product Service

    C->>E: GET /products
    Note over E: Overall timeout: 5s<br/>Per-try: 2s<br/>Attempts: 3

    E->>S: Attempt 1
    Note over E,S: ⏳ Waiting... 2 seconds
    Note over E: Per-try timeout! (2s)

    E->>E: Backoff: 25ms
    E->>S: Attempt 2
    Note over E,S: ⏳ Waiting... 2 seconds
    Note over E: Per-try timeout! (2s)

    E->>E: Backoff: 50ms
    E->>S: Attempt 3 (only 0.9s budget left)
    Note over E: ⏰ Overall timeout at 5s!
    Note over E: Attempt cancelled

    E-->>C: 504 Gateway Timeout ❌
```

## Retry Amplification Danger

```mermaid
graph TD
    U["👤 1 User Request"]
    A["Service A<br/>3 retries"]
    B["Service B<br/>3 retries"]
    C["Service C<br/>3 retries"]
    DB["💀 Database (down)"]

    U -->|"1 request"| A
    A -->|"3 requests"| B
    B -->|"9 requests<br/>(3 × 3)"| C
    C -->|"27 requests<br/>(3 × 3 × 3)"| DB

    style U fill:#2196F3,color:#fff
    style DB fill:#f44336,color:#fff
    style A fill:#FF9800,color:#fff
    style B fill:#FF9800,color:#fff
    style C fill:#FF9800,color:#fff
```

## Exponential Backoff Between Retries

```mermaid
gantt
    title Exponential Backoff Timing
    dateFormat X
    axisFormat %sms

    section Retries
    Attempt 1          :a1, 0, 100
    Backoff 25ms       :crit, b1, 100, 125
    Attempt 2          :a2, 125, 225
    Backoff 50ms       :crit, b2, 225, 275
    Attempt 3          :a3, 275, 375
    Backoff 100ms      :crit, b3, 375, 475
    Attempt 4 (final)  :a4, 475, 575
```

## Gateway + Full Resource Chain

```mermaid
graph TB
    EXT["🌍 External Client"]

    subgraph "Istio Ingress Gateway"
        GW["👂 Gateway Envoy<br/>Port 80<br/>Host: product.example.com"]
    end

    subgraph "VirtualService (Retry/Timeout lives HERE)"
        VS["📋 route:<br/>  destination: product-svc<br/>retries:<br/>  attempts: 3<br/>  retryOn: 5xx<br/>timeout: 5s<br/>perTryTimeout: 2s"]
    end

    DR["🏷️ DestinationRule<br/>Subset definitions"]

    subgraph "Namespace"
        SVC["🔗 product-svc"]
        P1["📦 Product Pod 1"]
        P2["📦 Product Pod 2"]
    end

    EXT --> GW
    GW --> VS
    VS --> DR
    DR --> SVC
    SVC --> P1
    SVC --> P2

    style GW fill:#4CAF50,color:#fff
    style VS fill:#FF9800,color:#fff
    style DR fill:#2196F3,color:#fff
```

## End-to-End Request with Retries

```mermaid
sequenceDiagram
    participant EXT as External Client
    participant LB as LoadBalancer
    participant GW as Gateway Envoy
    participant SIDE as Sidecar Envoy<br/>(retry logic)
    participant APP as Product App

    EXT->>LB: GET /products
    LB->>GW: Forward to port 80
    GW->>GW: Gateway: host match ✅
    GW->>SIDE: Route via VirtualService

    SIDE->>APP: Attempt 1
    APP-->>SIDE: 503 Error ❌
    Note over SIDE: retryOn: 5xx → retry!

    SIDE->>APP: Attempt 2
    APP-->>SIDE: 200 OK ✅

    SIDE-->>EXT: 200 OK (client sees success!)
```

