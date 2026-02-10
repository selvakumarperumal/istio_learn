# Mutual TLS (mTLS) — Diagrams

## Overall Architecture

```mermaid
graph TB
    ISTIOD["🏛️ Istiod<br/>Certificate Authority"]
    
    subgraph "Pod A"
        APP_A["App A<br/>(plain HTTP)"]
        ENV_A["Envoy A<br/>Cert: svc-A"]
    end

    subgraph "Pod B"
        APP_B["App B<br/>(plain HTTP)"]
        ENV_B["Envoy B<br/>Cert: svc-B"]
    end

    ISTIOD -->|"Issue cert"| ENV_A
    ISTIOD -->|"Issue cert"| ENV_B
    APP_A -->|"HTTP"| ENV_A
    ENV_A <-->|"🔒 mTLS Tunnel"| ENV_B
    ENV_B -->|"HTTP"| APP_B

    style ISTIOD fill:#9C27B0,color:#fff
    style ENV_A fill:#4CAF50,color:#fff
    style ENV_B fill:#4CAF50,color:#fff
```

## mTLS Handshake — Sequence

```mermaid
sequenceDiagram
    participant A as Envoy A (Client)
    participant B as Envoy B (Server)
    participant CA as Istio CA

    Note over A,CA: Certificate Distribution (at pod startup)
    CA->>A: Issue cert for "svc-A"
    CA->>B: Issue cert for "svc-B"

    Note over A,B: mTLS Handshake (every connection)
    A->>B: 1. ClientHello
    B->>A: 2. ServerHello + Certificate (svc-B)
    A->>A: 3. Verify svc-B cert against CA ✅
    A->>B: 4. Client Certificate (svc-A)
    B->>B: 5. Verify svc-A cert against CA ✅
    
    rect rgb(200, 255, 200)
        A->>B: 🔒 Encrypted data
        B->>A: 🔒 Encrypted response
        Note over A,B: All data encrypted with TLS 1.3
    end
```

## STRICT vs PERMISSIVE Mode

```mermaid
graph TB
    subgraph "STRICT Mode"
        S_WITH["Pod with Sidecar<br/>(has cert)"]
        S_WITHOUT["Pod without Sidecar<br/>(no cert)"]
        S_TARGET["Target Service<br/>STRICT"]
        S_WITH -->|"mTLS ✅"| S_TARGET
        S_WITHOUT -->|"Plain HTTP ❌<br/>REJECTED"| S_TARGET
    end

    subgraph "PERMISSIVE Mode"
        P_WITH["Pod with Sidecar<br/>(has cert)"]
        P_WITHOUT["Pod without Sidecar<br/>(no cert)"]
        P_TARGET["Target Service<br/>PERMISSIVE"]
        P_WITH -->|"mTLS ✅"| P_TARGET
        P_WITHOUT -->|"Plain HTTP ✅<br/>ALLOWED"| P_TARGET
    end

    style S_TARGET fill:#f44336,color:#fff
    style P_TARGET fill:#FF9800,color:#fff
    style S_WITH fill:#4CAF50,color:#fff
    style P_WITH fill:#4CAF50,color:#fff
    style S_WITHOUT fill:#9E9E9E,color:#fff
    style P_WITHOUT fill:#9E9E9E,color:#fff
```

## Certificate Identity Format

```mermaid
graph LR
    SA["ServiceAccount<br/>frontend-sa"]
    NS["Namespace<br/>production"]
    TD["Trust Domain<br/>cluster.local"]
    
    CERT["📜 Certificate Identity<br/>cluster.local/ns/production/sa/frontend-sa"]

    TD --> CERT
    NS --> CERT
    SA --> CERT

    style CERT fill:#2196F3,color:#fff
```

## Migration Path: PERMISSIVE → STRICT

```mermaid
stateDiagram-v2
    [*] --> NoMesh: No Istio

    NoMesh --> Permissive: Install Istio<br/>Add sidecars

    state Permissive {
        [*] --> Monitoring
        Monitoring: Accept both mTLS<br/>and plain HTTP
        Monitoring: Monitor connections
    }

    Permissive --> Strict: All services<br/>have sidecars

    state Strict {
        [*] --> Enforcing
        Enforcing: mTLS REQUIRED
        Enforcing: Plain HTTP rejected
    }

    Strict --> [*]: Secure ✅
```

## Without vs With mTLS

```mermaid
graph TB
    subgraph "❌ Without mTLS"
        A1["Pod A"] -->|"Plain HTTP<br/>👀 Readable<br/>✏️ Modifiable<br/>🎭 Spoofable"| B1["Pod B"]
        ATK1["🕵️ Attacker"] -.->|"Can sniff"| A1
    end

    subgraph "✅ With mTLS"
        A2["Pod A"] -->|"🔒 TLS 1.3<br/>Encrypted<br/>Integrity protected<br/>Identity verified"| B2["Pod B"]
        ATK2["🕵️ Attacker"] -.->|"Can't read ❌"| A2
    end

    style B1 fill:#f44336,color:#fff
    style B2 fill:#4CAF50,color:#fff
```

## Gateway + mTLS: External vs Internal Traffic

```mermaid
graph TB
    EXT["🌍 External Client<br/>(plain HTTPS or HTTP)"]

    subgraph "Istio Ingress Gateway"
        GW["👂 Gateway Envoy<br/>TLS termination here<br/>Port 443: HTTPS<br/>Port 80: HTTP"]
    end

    subgraph "Mesh Internal (auto mTLS)"
        subgraph "Pod A"
            ENVA["⚡ Envoy A"]
            APPA["App A"]
        end
        subgraph "Pod B"
            ENVB["⚡ Envoy B"]
            APPB["App B"]
        end
    end

    PA["🔒 PeerAuthentication<br/>mode: STRICT<br/>(applies to mesh-internal only)"]

    EXT -->|"HTTPS/HTTP"| GW
    GW -->|"🔒 mTLS (auto)"| ENVA
    ENVA -->|"plain HTTP"| APPA
    APPA -->|"plain HTTP"| ENVA
    ENVA <-->|"🔒 mTLS"| ENVB
    ENVB -->|"plain HTTP"| APPB
    PA -.->|"enforces"| ENVA
    PA -.->|"enforces"| ENVB

    style GW fill:#4CAF50,color:#fff
    style PA fill:#FF9800,color:#fff
```

## Full Traffic Path with Gateway + mTLS

```mermaid
sequenceDiagram
    participant EXT as External Client
    participant GW as Gateway Envoy
    participant EA as Envoy A (sidecar)
    participant AA as App A
    participant EB as Envoy B (sidecar)
    participant AB as App B

    EXT->>GW: HTTPS request (TLS terminated at Gateway)
    GW->>EA: mTLS connection (auto-encrypted)
    Note over GW,EA: Gateway cert ↔ Sidecar cert<br/>Both from Istio CA
    EA->>AA: Plain HTTP (localhost)
    AA->>EA: Call Service B (plain HTTP)
    EA->>EB: mTLS connection (auto-encrypted)
    Note over EA,EB: Both verify each other's<br/>identity via Istio CA
    EB->>AB: Plain HTTP (localhost)
    AB-->>EXT: Response (encrypted at every hop)
```

