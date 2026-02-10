# Circuit Breaker — Diagrams

## Overall Architecture

```mermaid
graph TB
    Client["🌐 Client (fortio)"]
    EP["⚡ Envoy Proxy<br/>Circuit Breaker"]
    P1["📦 httpbin Pod 1"]
    P2["📦 httpbin Pod 2"]
    P3["📦 httpbin Pod 3"]

    Client --> EP
    EP -->|"✅ Within limits"| P1
    EP -->|"✅ Within limits"| P2
    EP -->|"❌ Ejected (5xx errors)"| P3
    EP -->|"❌ 503 Overflow"| Client

    style EP fill:#FF5722,color:#fff
    style P1 fill:#4CAF50,color:#fff
    style P2 fill:#4CAF50,color:#fff
    style P3 fill:#f44336,color:#fff
```

## Connection Pool Overflow

```mermaid
sequenceDiagram
    participant C as Client (3 concurrent)
    participant E as Envoy Proxy
    participant H as httpbin

    Note over E: maxConnections: 1<br/>maxPendingRequests: 1

    C->>E: Request 1
    E->>E: Connections: 0/1 → OK
    E->>H: Forward (uses connection slot)
    Note over E: Connections: 1/1 (FULL)

    C->>E: Request 2 (Req 1 still processing)
    E->>E: Connections: 1/1 (FULL)<br/>Pending: 0/1 → Queue it
    Note over E: Pending: 1/1 (FULL)

    C->>E: Request 3 (Req 1 still processing)
    E->>E: Connections: 1/1 (FULL)<br/>Pending: 1/1 (FULL)
    E-->>C: ❌ 503 (overflow)

    H-->>E: Response to Req 1
    E-->>C: ✅ 200 OK (Request 1)
    E->>H: Forward Request 2 (from queue)
    H-->>E: Response to Req 2
    E-->>C: ✅ 200 OK (Request 2)
```

## Connection Pool State Machine

```mermaid
stateDiagram-v2
    [*] --> Available: Pool empty

    Available --> InUse: Request arrives<br/>(take connection)
    InUse --> Available: Request complete<br/>(release connection)
    InUse --> Queued: Pool full<br/>(wait in pending queue)
    Queued --> InUse: Connection freed
    InUse --> Overflow: Pool full AND<br/>Queue full
    Overflow --> [*]: Return 503

    state Available {
        [*] --> Ready
        Ready: connections < maxConnections
    }

    state InUse {
        [*] --> Processing
        Processing: connections = maxConnections
    }

    state Overflow {
        [*] --> Rejected
        Rejected: 503 Service Unavailable
    }
```

## Outlier Detection — Pod Ejection

```mermaid
sequenceDiagram
    participant LB as Envoy Load Balancer
    participant P1 as Pod 1 (healthy)
    participant P2 as Pod 2 (healthy)
    participant P3 as Pod 3 (buggy)

    Note over LB,P3: Phase 1: Error Detection
    LB->>P3: Request
    P3-->>LB: 500 Internal Server Error ❌
    LB->>LB: consecutive5xxErrors: 1 reached!

    Note over LB,P3: Phase 2: Ejection (30s)
    LB->>LB: Eject Pod 3 for 30s
    rect rgb(255, 200, 200)
        LB->>P1: Request → 200 ✅
        LB->>P2: Request → 200 ✅
        LB->>P1: Request → 200 ✅
        Note over P3: EJECTED<br/>No traffic for 30s
    end

    Note over LB,P3: Phase 3: Recovery Test
    LB->>P3: Test request after 30s
    alt Pod recovered
        P3-->>LB: 200 OK ✅
        LB->>LB: Re-add Pod 3 to pool
    else Still broken
        P3-->>LB: 500 Error ❌
        LB->>LB: Eject for 60s (2x longer)
    end
```

## Circuit Breaker State Diagram

```mermaid
stateDiagram-v2
    [*] --> Closed

    Closed --> Open: consecutive5xxErrors<br/>threshold reached
    Open --> HalfOpen: baseEjectionTime<br/>elapsed (30s)
    HalfOpen --> Closed: Test request<br/>succeeds ✅
    HalfOpen --> Open: Test request<br/>fails ❌ (eject 2x longer)

    state Closed {
        [*] --> Monitoring
        Monitoring: All pods active
        Monitoring: Counting errors
    }

    state Open {
        [*] --> Ejected
        Ejected: Faulty pod removed
        Ejected: Traffic to healthy pods only
    }

    state HalfOpen {
        [*] --> Testing
        Testing: Send 1 test request
        Testing: to ejected pod
    }
```

## Traffic Distribution During Overflow Test

```mermaid
pie title "30 requests with -c 3 (3 concurrent)"
    "200 OK (within limit)" : 10
    "503 Overflow (rejected)" : 20
```
