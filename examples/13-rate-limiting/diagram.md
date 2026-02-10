# Rate Limiting — Diagrams

## Overall Architecture

```mermaid
graph TB
    Client["🌐 Client (many requests)"]
    GW["🚪 Istio Gateway"]
    RL["🚰 Envoy Rate Limiter<br/>(local per-pod)"]
    APP["📦 httpbin Pod"]

    Client -->|"100 requests"| GW
    GW --> RL
    RL -->|"10 allowed ✅"| APP
    RL -->|"90 rejected ❌<br/>429 Too Many Requests"| Client

    style RL fill:#FF9800,color:#fff
    style APP fill:#4CAF50,color:#fff
```

## Token Bucket Algorithm

```mermaid
stateDiagram-v2
    [*] --> Full: Bucket starts full

    state Full {
        [*] --> Ready
        Ready: 10/10 tokens 🪙
    }

    Full --> Consuming: Request arrives<br/>(take 1 token)

    state Consuming {
        [*] --> Available
        Available: tokens > 0
        Available: Allow request ✅
    }

    Consuming --> Consuming: More requests<br/>(take tokens)
    Consuming --> Empty: Last token used

    state Empty {
        [*] --> Rejected
        Rejected: 0/10 tokens
        Rejected: Reject → 429 ❌
    }

    Empty --> Refilling: fill_interval elapsed

    state Refilling {
        [*] --> Adding
        Adding: Add tokens_per_fill
        Adding: Up to max_tokens
    }

    Refilling --> Consuming: Tokens available
```

## Token Bucket Timeline

```mermaid
gantt
    title Token Bucket: 10 tokens, refill 10 every 60s
    dateFormat X
    axisFormat %ss

    section Tokens
    Start: 10 tokens              :active, t1, 0, 1
    After 10 requests: 0 tokens   :crit, t2, 10, 11
    Refill at 60s: 10 tokens      :active, t3, 60, 61

    section Requests
    Requests 1-10: Allowed ✅     :done, r1, 0, 10
    Requests 11-15: Rejected 429  :crit, r2, 10, 15
    Wait for refill               :r3, 15, 60
    Requests 16-25: Allowed ✅    :done, r4, 60, 70
```

## Request Decision Flow

```mermaid
flowchart TD
    REQ["📨 Request arrives"]
    CHECK{"Tokens available<br/>in bucket?"}
    TAKE["Take 1 token<br/>Bucket: N-1"]
    ALLOW["✅ Forward to upstream<br/>200 OK"]
    REJECT["❌ Return immediately<br/>429 Too Many Requests"]

    REQ --> CHECK
    CHECK -->|"tokens > 0"| TAKE
    CHECK -->|"tokens = 0"| REJECT
    TAKE --> ALLOW

    style ALLOW fill:#4CAF50,color:#fff
    style REJECT fill:#f44336,color:#fff
```

## Local vs Global Rate Limiting

```mermaid
graph TB
    subgraph "Local Rate Limiting (per-pod)"
        LP1["Pod 1<br/>🪣 10 tokens/min"]
        LP2["Pod 2<br/>🪣 10 tokens/min"]
        LP3["Pod 3<br/>🪣 10 tokens/min"]
        LTOTAL["Total: 30 req/min<br/>(scales with pods)"]
    end

    subgraph "Global Rate Limiting (shared)"
        GP1["Pod 1"]
        GP2["Pod 2"]
        GP3["Pod 3"]
        REDIS["🗄️ Redis<br/>🪣 10 tokens/min"]
        GTOTAL["Total: exactly 10 req/min<br/>(fixed regardless of pods)"]
        GP1 --> REDIS
        GP2 --> REDIS
        GP3 --> REDIS
    end

    style LTOTAL fill:#FF9800,color:#fff
    style GTOTAL fill:#4CAF50,color:#fff
    style REDIS fill:#f44336,color:#fff
```

## Rate Limit Response Sequence

```mermaid
sequenceDiagram
    participant C as Client
    participant E as Envoy Rate Limiter
    participant A as App (httpbin)

    Note over E: Bucket: 3 tokens (for demo)

    C->>E: Request 1
    E->>E: Token: 3→2 ✅
    E->>A: Forward
    A-->>C: 200 OK

    C->>E: Request 2
    E->>E: Token: 2→1 ✅
    E->>A: Forward
    A-->>C: 200 OK

    C->>E: Request 3
    E->>E: Token: 1→0 ✅
    E->>A: Forward
    A-->>C: 200 OK

    C->>E: Request 4
    E->>E: Token: 0 ❌ EMPTY
    Note over E: App never called!
    E-->>C: 429 Too Many Requests
```

## Gateway + Rate Limiting (EnvoyFilter Location)

```mermaid
graph TB
    EXT["🌍 External Client<br/>(many requests)"]

    subgraph "Istio Ingress Gateway"
        GW["👂 Gateway Envoy<br/>Port 80"]
        EF["🚰 EnvoyFilter<br/>Local Rate Limit<br/>token_bucket:<br/>  max_tokens: 10<br/>  fill_interval: 60s"]
    end

    VS["📋 VirtualService<br/>Route to httpbin"]

    subgraph "Namespace"
        APP["📦 httpbin Pod"]
    end

    EXT --> GW
    GW --> EF
    EF -->|"tokens available ✅"| VS
    EF -->|"no tokens ❌"| REJECT["429 Too Many Requests"]
    VS --> APP

    style GW fill:#4CAF50,color:#fff
    style EF fill:#FF9800,color:#fff
    style REJECT fill:#f44336,color:#fff
```

## End-to-End with Gateway + Rate Limit

```mermaid
sequenceDiagram
    participant EXT as External Client
    participant LB as LoadBalancer
    participant GW as Gateway Envoy<br/>(EnvoyFilter applied)
    participant APP as httpbin Pod

    Note over GW: Token bucket: 3/3 (for demo)

    EXT->>LB: Request 1
    LB->>GW: Forward
    GW->>GW: Token: 3→2 ✅
    GW->>APP: Forward to httpbin
    APP-->>EXT: 200 OK

    EXT->>LB: Request 2
    LB->>GW: Forward
    GW->>GW: Token: 2→1 ✅
    GW->>APP: Forward
    APP-->>EXT: 200 OK

    EXT->>LB: Request 3
    LB->>GW: Forward
    GW->>GW: Token: 1→0 ✅
    GW->>APP: Forward
    APP-->>EXT: 200 OK

    EXT->>LB: Request 4
    LB->>GW: Forward
    GW->>GW: Token: 0 ❌ EMPTY
    Note over APP: Never called!
    GW-->>EXT: 429 Too Many Requests
```

