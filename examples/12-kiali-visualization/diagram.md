# Kiali Visualization — Diagrams

## Overall Architecture

```mermaid
graph TB
    subgraph "Data Sources"
        PROM["📊 Prometheus<br/>Traffic metrics"]
        K8S["☸️ Kubernetes API<br/>Config + resources"]
        JAEGER["🔍 Jaeger<br/>Distributed traces"]
    end

    KIALI["🗺️ Kiali Server<br/>:20001"]
    UI["🖥️ Browser<br/>Kiali Dashboard"]

    PROM -->|"request rate<br/>error rate<br/>latency"| KIALI
    K8S -->|"services<br/>deployments<br/>Istio config"| KIALI
    JAEGER -->|"traces<br/>spans"| KIALI
    KIALI -->|"serve UI"| UI

    style KIALI fill:#2196F3,color:#fff
    style PROM fill:#E65100,color:#fff
    style JAEGER fill:#4CAF50,color:#fff
```

## Service Graph — What Kiali Draws

```mermaid
graph LR
    FE["🟢 Frontend<br/>100% healthy"]
    PROD["🟢 Product<br/>100% healthy"]
    ORD["🟡 Orders<br/>95% healthy"]
    DB["🟢 Database<br/>100% healthy"]
    PAY["🔴 Payment<br/>50% errors"]

    FE -->|"80 req/s<br/>0% err 🔒"| PROD
    FE -->|"30 req/s<br/>5% err 🔒"| ORD
    PROD -->|"50 req/s<br/>0% err 🔒"| DB
    ORD -->|"20 req/s<br/>50% err 🔒"| PAY

    style FE fill:#4CAF50,color:#fff
    style PROD fill:#4CAF50,color:#fff
    style ORD fill:#FF9800,color:#fff
    style DB fill:#4CAF50,color:#fff
    style PAY fill:#f44336,color:#fff
```

## Kiali Features Overview

```mermaid
graph TD
    KIALI["🗺️ Kiali"]
    
    GRAPH["📊 Graph<br/>Live topology map"]
    HEALTH["💚 Health<br/>Service health status"]
    CONFIG["⚙️ Config<br/>Istio YAML validation"]
    TRACES["🔍 Traces<br/>Jaeger integration"]
    LOGS["📝 Logs<br/>Pod log viewer"]
    WIZARD["🧙 Wizards<br/>Create Istio resources"]

    KIALI --> GRAPH
    KIALI --> HEALTH
    KIALI --> CONFIG
    KIALI --> TRACES
    KIALI --> LOGS
    KIALI --> WIZARD

    style KIALI fill:#2196F3,color:#fff
    style GRAPH fill:#4CAF50,color:#fff
    style HEALTH fill:#4CAF50,color:#fff
    style CONFIG fill:#FF9800,color:#fff
    style TRACES fill:#9C27B0,color:#fff
```

## Config Validation Flow

```mermaid
flowchart TD
    FETCH["Fetch Istio resources<br/>from Kubernetes API"]
    PARSE["Parse VirtualService,<br/>DestinationRule, etc."]
    CHECK1{"Subset references<br/>valid?"}
    CHECK2{"Host references<br/>valid?"}
    CHECK3{"Weight totals<br/>= 100?"}
    
    VALID["✅ Valid Configuration"]
    INVALID["❌ Error Found<br/>Show warning in UI"]

    FETCH --> PARSE
    PARSE --> CHECK1
    CHECK1 -->|"Yes"| CHECK2
    CHECK1 -->|"No"| INVALID
    CHECK2 -->|"Yes"| CHECK3
    CHECK2 -->|"No"| INVALID
    CHECK3 -->|"Yes"| VALID
    CHECK3 -->|"No"| INVALID

    style VALID fill:#4CAF50,color:#fff
    style INVALID fill:#f44336,color:#fff
```

## Health Status Calculation

```mermaid
graph LR
    subgraph "Error Rate Thresholds"
        GREEN["🟢 Healthy<br/>Error rate < 0.1%"]
        YELLOW["🟡 Degraded<br/>Error rate 0.1% - 10%"]
        RED["🔴 Failure<br/>Error rate > 10%"]
    end

    METRIC["istio_requests_total<br/>{response_code=~'5.*'}"]
    METRIC -->|"calculate ratio"| GREEN
    METRIC -->|"calculate ratio"| YELLOW
    METRIC -->|"calculate ratio"| RED

    style GREEN fill:#4CAF50,color:#fff
    style YELLOW fill:#FF9800,color:#fff
    style RED fill:#f44336,color:#fff
```

## Gateway in Kiali's Service Graph

```mermaid
graph LR
    EXT["🌍 External Traffic"]

    subgraph "Kiali Service Graph View"
        GW["🚪 istio-ingressgateway<br/>🟢 Healthy<br/>150 req/s"]
        FE["📦 Frontend<br/>🟢 100% healthy"]
        PROD["📦 Product<br/>🟢 100% healthy"]
        ORD["📦 Orders<br/>🟡 95% healthy"]
        PAY["📦 Payment<br/>🔴 50% errors"]
    end

    EXT -->|"all ingress"| GW
    GW -->|"80 req/s 🔒"| FE
    FE -->|"50 req/s 🔒"| PROD
    FE -->|"30 req/s 🔒"| ORD
    ORD -->|"20 req/s 🔒"| PAY

    style GW fill:#4CAF50,color:#fff
    style FE fill:#4CAF50,color:#fff
    style PROD fill:#4CAF50,color:#fff
    style ORD fill:#FF9800,color:#fff
    style PAY fill:#f44336,color:#fff
```

## Gateway Config Validation in Kiali

```mermaid
graph TB
    subgraph "Kiali Validates"
        GW_CHECK["✅ Gateway<br/>Port 80 configured<br/>Host matches VirtualService"]
        VS_CHECK["✅ VirtualService<br/>References valid Gateway<br/>Destination host exists"]
        DR_CHECK["✅ DestinationRule<br/>Subsets match deployment labels"]
        SE_CHECK["⚠️ ServiceEntry<br/>Unreferenced by any VS"]
    end

    style GW_CHECK fill:#4CAF50,color:#fff
    style VS_CHECK fill:#4CAF50,color:#fff
    style DR_CHECK fill:#4CAF50,color:#fff
    style SE_CHECK fill:#FF9800,color:#fff
```

