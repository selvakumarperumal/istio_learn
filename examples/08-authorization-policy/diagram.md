# Authorization Policy — Diagrams

## Overall Architecture

```mermaid
graph TB
    subgraph "Namespace: my-app"
        FE["📦 Frontend<br/>SA: frontend-sa"]
        ORD["📦 Orders<br/>SA: orders-sa"]
        DB["📦 Database<br/>SA: database-sa"]
        
        FE -->|"✅ Allowed<br/>(policy exists)"| ORD
        FE -->|"❌ Denied<br/>(no policy)"| DB
        ORD -->|"✅ Allowed<br/>(policy exists)"| DB
    end

    DENY["🔒 deny-all policy<br/>(baseline)"]
    ALLOW1["✅ allow-frontend-to-orders"]
    ALLOW2["✅ allow-orders-to-database"]

    DENY -.->|"applies to namespace"| FE
    DENY -.->|"applies to namespace"| ORD
    DENY -.->|"applies to namespace"| DB

    style DENY fill:#f44336,color:#fff
    style ALLOW1 fill:#4CAF50,color:#fff
    style ALLOW2 fill:#4CAF50,color:#fff
```

## Authorization Decision Flow

```mermaid
flowchart TD
    REQ["📨 Request arrives at<br/>destination Envoy"]
    CUSTOM{"CUSTOM policies<br/>exist?"}
    CUSTOM_CHECK{"External auth<br/>approves?"}
    DENY_CHECK{"Matches any<br/>DENY policy?"}
    ALLOW_CHECK{"Matches any<br/>ALLOW policy?"}
    ALLOW_EXIST{"Any ALLOW<br/>policies exist?"}
    
    ALLOWED["✅ ALLOW<br/>Request proceeds"]
    DENIED["❌ DENY<br/>403 Forbidden"]

    REQ --> CUSTOM
    CUSTOM -->|"Yes"| CUSTOM_CHECK
    CUSTOM -->|"No"| DENY_CHECK
    CUSTOM_CHECK -->|"Approved"| DENY_CHECK
    CUSTOM_CHECK -->|"Rejected"| DENIED
    DENY_CHECK -->|"Match"| DENIED
    DENY_CHECK -->|"No match"| ALLOW_CHECK
    ALLOW_CHECK -->|"Match"| ALLOWED
    ALLOW_CHECK -->|"No match"| ALLOW_EXIST
    ALLOW_EXIST -->|"Yes (ALLOW policies exist)"| DENIED
    ALLOW_EXIST -->|"No (no ALLOW policies)"| ALLOWED

    style ALLOWED fill:#4CAF50,color:#fff
    style DENIED fill:#f44336,color:#fff
```

## Policy Evaluation — Sequence

```mermaid
sequenceDiagram
    participant FE as Frontend (frontend-sa)
    participant E as Envoy on Orders Pod
    participant ORD as Orders App

    Note over E: Policies loaded:<br/>1. deny-all<br/>2. allow-frontend-to-orders

    FE->>E: GET /api/orders/123
    E->>E: Check DENY policies → no match
    E->>E: Check ALLOW policies
    E->>E: Source: frontend-sa ✅
    E->>E: Method: GET ✅
    E->>E: Path: /api/orders/* ✅
    E->>ORD: Forward request ✅
    ORD-->>FE: 200 OK

    Note over FE,ORD: Denied scenario
    FE->>E: DELETE /admin/drop-tables
    E->>E: Check DENY policies → no match
    E->>E: Check ALLOW policies
    E->>E: Source: frontend-sa ✅
    E->>E: Method: DELETE ❌ (only GET allowed)
    E-->>FE: 403 Forbidden ❌
```

## Zero-Trust Layered Security

```mermaid
graph TB
    subgraph "Layer 1: Network"
        NP["Network Policy<br/>IP-based firewall"]
    end

    subgraph "Layer 2: Identity (mTLS)"
        MTLS["PeerAuthentication<br/>WHO are you?"]
    end

    subgraph "Layer 3: Authorization"
        AUTHZ["AuthorizationPolicy<br/>WHAT can you do?"]
    end

    subgraph "Layer 4: Application"
        APP["App Logic<br/>Business rules"]
    end

    NP --> MTLS --> AUTHZ --> APP

    style NP fill:#607D8B,color:#fff
    style MTLS fill:#2196F3,color:#fff
    style AUTHZ fill:#FF9800,color:#fff
    style APP fill:#4CAF50,color:#fff
```

## DENY vs ALLOW Priority

```mermaid
graph LR
    REQ["Request"]
    
    DENY["🛑 DENY Policy<br/>Blocks admin paths"]
    ALLOW["✅ ALLOW Policy<br/>Allows frontend"]
    
    RESULT["❌ DENIED<br/>DENY always wins!"]

    REQ --> DENY
    REQ --> ALLOW
    DENY -->|"DENY wins"| RESULT
    ALLOW -.->|"overridden"| RESULT

    style DENY fill:#f44336,color:#fff
    style ALLOW fill:#4CAF50,color:#fff
    style RESULT fill:#f44336,color:#fff
```

## ServiceAccount Identity

```mermaid
graph TD
    POD["📦 Pod"]
    SA["🪪 ServiceAccount<br/>frontend-sa"]
    CERT["📜 mTLS Certificate<br/>from Istio CA"]
    PRINCIPAL["🆔 Principal Identity<br/>cluster.local/ns/default/sa/frontend-sa"]
    POLICY["📋 AuthorizationPolicy<br/>checks principal"]

    POD -->|"runs as"| SA
    SA -->|"Istio issues"| CERT
    CERT -->|"contains"| PRINCIPAL
    PRINCIPAL -->|"matched by"| POLICY

    style PRINCIPAL fill:#2196F3,color:#fff
    style POLICY fill:#FF9800,color:#fff
```
