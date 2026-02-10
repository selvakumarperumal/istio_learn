# Egress Traffic — Diagrams

## Overall Architecture

```mermaid
graph TB
    subgraph "Kubernetes Cluster"
        POD["📦 App Pod"]
        ENV["⚡ Envoy Sidecar"]
        REG["📋 Service Registry<br/>(ServiceEntries)"]
    end

    EXT_OK["✅ httpbin.org<br/>(registered)"]
    EXT_BAD["❌ evil-server.com<br/>(not registered)"]

    POD --> ENV
    ENV -->|"Check registry"| REG
    REG -->|"Found"| EXT_OK
    REG -->|"Not found"| EXT_BAD

    style EXT_OK fill:#4CAF50,color:#fff
    style EXT_BAD fill:#f44336,color:#fff
    style REG fill:#FF9800,color:#fff
```

## ALLOW_ANY vs REGISTRY_ONLY

```mermaid
graph TB
    subgraph "ALLOW_ANY (Default)"
        A_POD["Pod"] --> A_ANY["Any external URL ✅"]
        A_RISK["⚠️ No control<br/>Data exfiltration possible"]
    end

    subgraph "REGISTRY_ONLY (Secure)"
        R_POD["Pod"] --> R_CHECK{"In ServiceEntry<br/>registry?"}
        R_CHECK -->|"Yes"| R_OK["✅ Allowed"]
        R_CHECK -->|"No"| R_BLOCK["❌ Blocked"]
    end

    style A_RISK fill:#f44336,color:#fff
    style R_OK fill:#4CAF50,color:#fff
    style R_BLOCK fill:#f44336,color:#fff
```

## ServiceEntry — How External Services Are Registered

```mermaid
graph LR
    SE["📋 ServiceEntry<br/>hosts: httpbin.org<br/>ports: 80, 443<br/>resolution: DNS<br/>location: MESH_EXTERNAL"]
    
    REG["Istio Service Registry"]
    DNS["DNS Resolution<br/>httpbin.org → 3.215.65.10"]
    
    SE -->|"registers"| REG
    REG -->|"resolve"| DNS

    style SE fill:#2196F3,color:#fff
    style REG fill:#FF9800,color:#fff
```

## Request Flow Decision — Sequence

```mermaid
sequenceDiagram
    participant APP as App
    participant E as Envoy Sidecar
    participant REG as Service Registry
    participant EXT as External Service

    Note over APP,EXT: Scenario 1: Registered service
    APP->>E: GET https://httpbin.org/get
    E->>REG: Is "httpbin.org" registered?
    REG-->>E: YES (ServiceEntry found) ✅
    E->>E: DNS resolve httpbin.org
    E->>EXT: Forward request
    EXT-->>APP: 200 OK

    Note over APP,EXT: Scenario 2: Unregistered service
    APP->>E: GET https://evil-server.com/steal
    E->>REG: Is "evil-server.com" registered?
    REG-->>E: NO ❌
    E-->>APP: 502 Bad Gateway
    Note over EXT: Never contacted!
```

## Security Comparison

```mermaid
graph TB
    subgraph "❌ Without Egress Control"
        C1["Compromised Pod"]
        C1 -->|"Send stolen data"| BAD1["evil-server.com"]
        C1 -->|"Download malware"| BAD2["malware.io"]
        C1 -->|"Crypto mining"| BAD3["crypto-miner.com"]
        RESULT1["💥 DATA BREACH"]
    end

    subgraph "✅ With REGISTRY_ONLY"
        C2["Compromised Pod"]
        C2 -->|"Allowed"| GOOD1["api.stripe.com ✅"]
        C2 -->|"BLOCKED"| BAD4["evil-server.com ❌"]
        C2 -->|"BLOCKED"| BAD5["malware.io ❌"]
        RESULT2["🔒 DATA SAFE"]
    end

    style RESULT1 fill:#f44336,color:#fff
    style RESULT2 fill:#4CAF50,color:#fff
    style BAD1 fill:#f44336,color:#fff
    style BAD2 fill:#f44336,color:#fff
    style BAD3 fill:#f44336,color:#fff
    style BAD4 fill:#f44336,color:#fff
    style BAD5 fill:#f44336,color:#fff
    style GOOD1 fill:#4CAF50,color:#fff
```

## Migration Strategy

```mermaid
stateDiagram-v2
    [*] --> AllowAny: Start

    state AllowAny {
        [*] --> Open
        Open: All outbound traffic allowed
        Open: Catalog external dependencies
    }

    AllowAny --> CreateEntries: List all external services

    state CreateEntries {
        [*] --> Register
        Register: Create ServiceEntry for each
        Register: approved external service
    }

    CreateEntries --> RegistryOnly: All services registered

    state RegistryOnly {
        [*] --> Locked
        Locked: Only registered services reachable
        Locked: Unknown destinations blocked
    }

    RegistryOnly --> [*]: Secure ✅
```

## Ingress vs Egress Gateway

```mermaid
graph LR
    EXT_IN["🌍 External Client<br/>(inbound)"]

    subgraph "Istio Mesh"
        IGW["🚪 Ingress Gateway<br/>Controls INBOUND traffic"]
        APP["📦 App Pods"]
        EGW["🚪 Egress Gateway<br/>Controls OUTBOUND traffic"]
    end

    EXT_OUT["🌍 External APIs<br/>(outbound)"]

    EXT_IN -->|"incoming requests"| IGW
    IGW --> APP
    APP --> EGW
    EGW -->|"outgoing requests<br/>(controlled)"| EXT_OUT

    style IGW fill:#4CAF50,color:#fff
    style EGW fill:#FF9800,color:#fff
```

## Egress Gateway Flow

```mermaid
graph TB
    POD["📦 App Pod"]
    SIDE["⚡ Sidecar Envoy"]
    
    subgraph "Egress Gateway"
        EGW["👂 Egress Gateway Envoy<br/>Logs all outbound traffic<br/>Enforces policies"]
    end

    SE["📋 ServiceEntry<br/>hosts: httpbin.org<br/>location: MESH_EXTERNAL"]
    VS["📋 VirtualService<br/>Route through egress GW"]

    EXT["🌍 httpbin.org"]

    POD --> SIDE
    SIDE -->|"route via"| VS
    VS -->|"through egress"| EGW
    SE -.->|"registers"| EXT
    EGW -->|"allowed ✅"| EXT

    style EGW fill:#FF9800,color:#fff
    style SE fill:#2196F3,color:#fff
```

## End-to-End with Egress Gateway

```mermaid
sequenceDiagram
    participant APP as App Pod
    participant SIDE as Sidecar Envoy
    participant EGW as Egress Gateway
    participant EXT as httpbin.org

    APP->>SIDE: GET https://httpbin.org/get
    SIDE->>SIDE: Check ServiceEntry registry
    Note over SIDE: httpbin.org registered ✅

    SIDE->>EGW: Route through Egress Gateway<br/>(via VirtualService)
    EGW->>EGW: Log: outbound to httpbin.org
    EGW->>EGW: Apply policies (TLS, auth)
    EGW->>EXT: Forward to httpbin.org
    EXT-->>APP: 200 OK

    Note over SIDE,EGW: Without Egress Gateway:<br/>pod → directly to internet (no logging/control)
```

