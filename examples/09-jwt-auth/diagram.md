# JWT Authentication — Diagrams

## Overall Architecture

```mermaid
graph TB
    Client["🌐 Client<br/>+ JWT Token"]
    GW["🚪 Gateway"]
    EP["⚡ Envoy Proxy"]
    JWKS["🔑 JWKS Endpoint<br/>(public keys)"]
    APP["📦 httpbin Pod"]

    Client -->|"Authorization: Bearer <JWT>"| GW
    GW --> EP
    EP -->|"Download keys"| JWKS
    EP -->|"Token valid ✅"| APP
    EP -->|"Token invalid ❌"| Client

    style EP fill:#FF9800,color:#fff
    style JWKS fill:#9C27B0,color:#fff
    style APP fill:#4CAF50,color:#fff
```

## JWT Token Structure

```mermaid
graph LR
    subgraph "JWT Token (3 parts separated by dots)"
        H["🔵 Header<br/>eyJhbGci...<br/>Algorithm: RS256<br/>Type: JWT"]
        P["🟢 Payload<br/>eyJpc3Mi...<br/>iss: issuer<br/>sub: subject<br/>exp: expiry<br/>groups: [...]"]
        S["🔴 Signature<br/>dL5GR...<br/>sign(header+payload,<br/>private_key)"]
    end

    H --- P --- S

    style H fill:#2196F3,color:#fff
    style P fill:#4CAF50,color:#fff
    style S fill:#f44336,color:#fff
```

## JWT Validation Flow

```mermaid
flowchart TD
    REQ["📨 Request arrives"]
    HAS_JWT{"Has Authorization<br/>Bearer header?"}
    EXTRACT["Extract JWT token"]
    VERIFY_SIG{"Signature valid?<br/>(check with JWKS)"}
    CHECK_EXP{"Token expired?<br/>(check exp claim)"}
    CHECK_ISS{"Issuer matches?<br/>(check iss claim)"}
    AUTHZ{"AuthorizationPolicy<br/>claims match?"}
    
    PASS_NO_JWT["✅ Pass through<br/>(no token to validate)"]
    REJECT_401["❌ 401 Unauthorized"]
    REJECT_403["❌ 403 Forbidden"]
    ALLOW["✅ Request forwarded"]

    REQ --> HAS_JWT
    HAS_JWT -->|"No"| PASS_NO_JWT
    HAS_JWT -->|"Yes"| EXTRACT
    EXTRACT --> VERIFY_SIG
    VERIFY_SIG -->|"Invalid"| REJECT_401
    VERIFY_SIG -->|"Valid"| CHECK_EXP
    CHECK_EXP -->|"Expired"| REJECT_401
    CHECK_EXP -->|"Valid"| CHECK_ISS
    CHECK_ISS -->|"Wrong issuer"| REJECT_401
    CHECK_ISS -->|"Matches"| AUTHZ
    AUTHZ -->|"Claims match"| ALLOW
    AUTHZ -->|"No match"| REJECT_403

    style ALLOW fill:#4CAF50,color:#fff
    style REJECT_401 fill:#f44336,color:#fff
    style REJECT_403 fill:#f44336,color:#fff
    style PASS_NO_JWT fill:#FF9800,color:#fff
```

## JWKS Key Verification

```mermaid
sequenceDiagram
    participant C as Client
    participant E as Envoy Proxy
    participant JWKS as JWKS URL (GitHub/Auth0)
    participant APP as httpbin

    Note over E,JWKS: At startup or cache refresh
    E->>JWKS: GET /.well-known/jwks.json
    JWKS-->>E: {"keys": [{"kty":"RSA", "n":"...", "e":"AQAB"}]}
    Note over E: Cache public keys

    C->>E: Request + Bearer <JWT>
    E->>E: Decode JWT header → get key ID
    E->>E: Find matching key in cached JWKS
    E->>E: Verify signature with public key ✅
    E->>E: Check expiration ✅
    E->>E: Check issuer ✅
    E->>APP: Forward to httpbin
    APP-->>C: 200 OK
```

## Two Resources Working Together

```mermaid
graph TB
    subgraph "RequestAuthentication"
        RA["Validates token:<br/>• Signature correct?<br/>• Not expired?<br/>• Trusted issuer?"]
    end

    subgraph "AuthorizationPolicy"
        AP["Checks claims:<br/>• Has required role?<br/>• Correct principal?<br/>• Right groups?"]
    end

    REQ["📨 Request + JWT"] --> RA
    RA -->|"Token valid"| AP
    RA -->|"Token invalid"| R401["401 Unauthorized"]
    AP -->|"Claims match"| OK["✅ Allow"]
    AP -->|"Claims don't match"| R403["403 Forbidden"]

    style RA fill:#2196F3,color:#fff
    style AP fill:#FF9800,color:#fff
    style OK fill:#4CAF50,color:#fff
    style R401 fill:#f44336,color:#fff
    style R403 fill:#f44336,color:#fff
```

## JWT vs mTLS vs API Key

```mermaid
graph LR
    subgraph "JWT Token"
        JWT["🎫 End-user identity<br/>Claims: roles, groups<br/>Expires: yes<br/>Provider: Auth0, Keycloak"]
    end

    subgraph "mTLS Certificate"
        MTLS["🔒 Service identity<br/>Claims: ServiceAccount<br/>Auto-rotated: 24h<br/>Provider: Istio CA"]
    end

    subgraph "API Key"
        KEY["🔑 App identity<br/>Claims: none<br/>Expires: usually no<br/>Provider: manual"]
    end

    style JWT fill:#2196F3,color:#fff
    style MTLS fill:#4CAF50,color:#fff
    style KEY fill:#FF9800,color:#fff
```

## Gateway + JWT Authentication Path

```mermaid
graph TB
    EXT["🌍 External Client<br/>+ Authorization: Bearer JWT"]

    subgraph "Istio Ingress Gateway"
        GW["👂 Gateway Envoy<br/>Port 80"]
        RA["📋 RequestAuthentication<br/>Validates JWT signature<br/>Checks issuer, expiry"]
        AP["🔒 AuthorizationPolicy<br/>Checks JWT claims"]
    end

    VS["📋 VirtualService<br/>Route to httpbin"]

    subgraph "jwt-demo Namespace"
        APP["📦 httpbin Pod"]
    end

    JWKS["🔑 JWKS Endpoint<br/>(GitHub/Auth0)"]

    EXT --> GW
    GW --> RA
    RA -->|"fetch keys"| JWKS
    RA -->|"token valid"| AP
    RA -->|"token invalid"| REJECT1["❌ 401"]
    AP -->|"claims match"| VS
    AP -->|"wrong claims"| REJECT2["❌ 403"]
    VS --> APP

    style GW fill:#4CAF50,color:#fff
    style RA fill:#2196F3,color:#fff
    style AP fill:#FF9800,color:#fff
    style REJECT1 fill:#f44336,color:#fff
    style REJECT2 fill:#f44336,color:#fff
```

## End-to-End with Gateway + JWT

```mermaid
sequenceDiagram
    participant EXT as External Client
    participant GW as Gateway Envoy
    participant JWKS as JWKS Endpoint
    participant APP as httpbin Pod

    Note over GW,JWKS: At startup
    GW->>JWKS: GET /.well-known/jwks.json
    JWKS-->>GW: Public keys cached ✅

    EXT->>GW: GET /get + Bearer <JWT>
    GW->>GW: RequestAuthentication:<br/>verify signature with cached key
    GW->>GW: Check expiry, issuer ✅
    GW->>GW: AuthorizationPolicy:<br/>check claims (groups, role)
    GW->>APP: Forward to httpbin
    APP-->>EXT: 200 OK ✅

    Note over EXT,APP: Without valid JWT
    EXT->>GW: GET /get (no token)
    GW-->>EXT: 401 Unauthorized ❌
```

