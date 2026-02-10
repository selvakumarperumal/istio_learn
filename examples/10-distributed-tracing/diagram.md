# Distributed Tracing — Diagrams

## Overall Architecture

```mermaid
graph TB
    Client["🌐 Client"]
    
    subgraph "Service Mesh"
        FE["📦 Frontend<br/>+ Envoy"]
        PROD["📦 Product<br/>+ Envoy"]
        INV["📦 Inventory<br/>+ Envoy"]
        PRICE["📦 Pricing<br/>+ Envoy"]
    end

    JAEGER["🔍 Jaeger<br/>Trace Collector"]

    Client --> FE
    FE --> PROD
    FE --> INV
    PROD --> PRICE

    FE -.->|"span"| JAEGER
    PROD -.->|"span"| JAEGER
    INV -.->|"span"| JAEGER
    PRICE -.->|"span"| JAEGER

    style JAEGER fill:#2196F3,color:#fff
```

## Trace and Span Hierarchy

```mermaid
gantt
    title Trace abc-123: Full Request Lifecycle
    dateFormat X
    axisFormat %sms

    section Frontend
    frontend GET /page                :active, fe, 0, 1000

    section Product
    product GET /info                 :prod, 50, 250

    section Inventory
    inventory GET /stock              :crit, inv, 100, 820

    section Pricing
    pricing GET /price                :price, 260, 310
```

## Header Propagation — How Spans Link Together

```mermaid
sequenceDiagram
    participant C as Client
    participant FE as Frontend (Envoy)
    participant PROD as Product (Envoy)
    participant DB as Database (Envoy)

    Note over C,DB: Trace ID: abc-123

    C->>FE: GET /page
    Note over FE: Envoy creates Span 1<br/>x-b3-traceid: abc-123<br/>x-b3-spanid: span-1

    FE->>PROD: GET /info<br/>x-b3-traceid: abc-123<br/>x-b3-spanid: span-2<br/>x-b3-parentspanid: span-1
    Note over FE: App MUST forward<br/>trace headers!

    PROD->>DB: GET /data<br/>x-b3-traceid: abc-123<br/>x-b3-spanid: span-3<br/>x-b3-parentspanid: span-2

    DB-->>PROD: 200 OK
    PROD-->>FE: 200 OK
    FE-->>C: 200 OK

    Note over C,DB: All 3 spans linked by trace ID abc-123
```

## With vs Without Header Propagation

```mermaid
graph TB
    subgraph "✅ Headers Propagated"
        T1["Trace: abc-123"]
        S1["Span 1: Frontend"]
        S2["Span 2: Product"]
        S3["Span 3: Database"]
        T1 --> S1 --> S2 --> S3
    end

    subgraph "❌ Headers NOT Propagated"
        T2["Trace: abc-123"]
        T3["Trace: xyz-789"]
        T4["Trace: mno-456"]
        S4["Span: Frontend"]
        S5["Span: Product"]
        S6["Span: Database"]
        T2 --> S4
        T3 --> S5
        T4 --> S6
    end

    style T1 fill:#4CAF50,color:#fff
    style T2 fill:#f44336,color:#fff
    style T3 fill:#f44336,color:#fff
    style T4 fill:#f44336,color:#fff
```

## Trace Data Flow

```mermaid
graph LR
    ENV["⚡ Envoy Sidecars<br/>(generate spans)"]
    COLL["📥 Jaeger Collector<br/>(receives spans)"]
    STORE["💾 Storage<br/>(Elasticsearch/Cassandra)"]
    UI["🖥️ Jaeger UI<br/>(query + visualize)"]
    USER["👤 Developer"]

    ENV -->|"UDP/HTTP"| COLL
    COLL -->|"store"| STORE
    STORE -->|"query"| UI
    UI -->|"view traces"| USER

    style ENV fill:#FF9800,color:#fff
    style COLL fill:#2196F3,color:#fff
    style STORE fill:#607D8B,color:#fff
    style UI fill:#4CAF50,color:#fff
```

## Sampling Decision

```mermaid
flowchart TD
    REQ["📨 Request arrives"]
    SAMPLE{"Sampling rate<br/>check (e.g., 1%)"}
    TRACE["📝 Create trace<br/>Generate spans<br/>Send to Jaeger"]
    SKIP["⏭️ Skip tracing<br/>Normal processing only"]

    REQ --> SAMPLE
    SAMPLE -->|"Within 1%"| TRACE
    SAMPLE -->|"Outside 1%"| SKIP

    style TRACE fill:#4CAF50,color:#fff
    style SKIP fill:#9E9E9E,color:#fff
```
