# Fault Injection — Diagrams

## Overall Architecture

```mermaid
graph TB
    Client["🌐 Client"]
    GW["🚪 Istio Gateway"]
    EP["⚡ Envoy Proxy<br/>(Fault Injection Filter)"]
    HTTP["📦 httpbin Pod"]

    Client -->|"HTTP request"| GW
    GW --> EP
    EP -->|"Normal path"| HTTP
    EP -->|"Abort path<br/>(503 immediately)"| Client
    EP -->|"Delay path<br/>(wait 5s then forward)"| HTTP

    style GW fill:#4CAF50,color:#fff
    style EP fill:#FF5722,color:#fff
    style HTTP fill:#2196F3,color:#fff
```

## Fault Decision Flow

```mermaid
flowchart TD
    REQ["📨 Request Arrives at Envoy"]
    ABORT{"🎲 Abort Check<br/>Roll dice: within X%?"}
    DELAY{"🎲 Delay Check<br/>Roll dice: within Y%?"}
    A503["❌ Return 503 Immediately<br/>(httpbin NEVER called)"]
    WAIT["⏳ Wait fixedDelay seconds"]
    FWD["✅ Forward to httpbin"]
    RESP["📤 Return 200 OK"]

    REQ --> ABORT
    ABORT -->|"YES (e.g. 20%)"| A503
    ABORT -->|"NO (e.g. 80%)"| DELAY
    DELAY -->|"YES (e.g. 30%)"| WAIT
    DELAY -->|"NO (e.g. 70%)"| FWD
    WAIT --> FWD
    FWD --> RESP

    style REQ fill:#607D8B,color:#fff
    style A503 fill:#f44336,color:#fff
    style WAIT fill:#FF9800,color:#fff
    style RESP fill:#4CAF50,color:#fff
```

## Combined Fault — Traffic Distribution

```mermaid
pie title "Combined Fault: 20% Abort + 30% Delay (of remaining)"
    "Aborted (503, fast)" : 20
    "Delayed (200, slow ~5s)" : 24
    "Normal (200, fast)" : 56
```

## Delay Injection — Sequence

```mermaid
sequenceDiagram
    participant C as Client
    participant E as Envoy Sidecar
    participant H as httpbin Pod

    Note over C,H: Request WITHOUT delay (50% chance)
    C->>E: GET /get
    E->>E: Dice roll: 73 (> 50) → No delay
    E->>H: Forward immediately
    H-->>E: 200 OK (20ms)
    E-->>C: 200 OK (total: 20ms)

    Note over C,H: Request WITH delay (50% chance)
    C->>E: GET /get
    E->>E: Dice roll: 31 (< 50) → Apply delay!
    E->>E: ⏳ Sleep 5 seconds...
    E->>H: Forward after 5s
    H-->>E: 200 OK (20ms)
    E-->>C: 200 OK (total: 5020ms)
```

## Abort Injection — Sequence

```mermaid
sequenceDiagram
    participant C as Client
    participant E as Envoy Sidecar
    participant H as httpbin Pod

    Note over C,H: Request WITHOUT abort (50% chance)
    C->>E: GET /get
    E->>E: Dice roll: 88 (> 50) → No fault
    E->>H: Forward normally
    H-->>E: 200 OK
    E-->>C: 200 OK ✅

    Note over C,H: Request WITH abort (50% chance)
    C->>E: GET /get
    E->>E: Dice roll: 12 (< 50) → ABORT!
    Note over E: httpbin is NEVER called
    E-->>C: 503 Service Unavailable ❌
```

## Multiple VirtualService Conflict

```mermaid
graph TB
    subgraph "❌ WRONG: Multiple VirtualServices"
        VS1["VS: httpbin-delay<br/>host: httpbin"]
        VS2["VS: httpbin-abort<br/>host: httpbin"]
        VS3["VS: httpbin-combined<br/>host: httpbin"]
        CHAOS["💥 Undefined Behavior<br/>Random 503 errors"]
        VS1 --> CHAOS
        VS2 --> CHAOS
        VS3 --> CHAOS
    end

    subgraph "✅ CORRECT: Only one VirtualService"
        VS4["VS: httpbin-delay<br/>host: httpbin"]
        OK["🎯 Predictable Behavior<br/>50% delayed, 50% normal"]
        VS4 --> OK
    end

    style CHAOS fill:#f44336,color:#fff
    style OK fill:#4CAF50,color:#fff
```
