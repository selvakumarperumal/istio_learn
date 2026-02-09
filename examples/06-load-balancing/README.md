# Load Balancing with Istio

## Overview
Configure different load balancing algorithms: Round Robin, Random, Least Connections, and Consistent Hashing.

## Algorithms

```mermaid
flowchart TB
    subgraph "Load Balancing Algorithms"
        RR[Round Robin<br/>Default]
        RAND[Random]
        LC[Least Connections]
        CH[Consistent Hash]
    end
    
    subgraph "Use Cases"
        RR --> |"Even distribution"| UC1[General purpose]
        RAND --> |"Simple distribution"| UC2[Stateless services]
        LC --> |"Performance-based"| UC3[Variable load services]
        CH --> |"Session affinity"| UC4[Stateful services]
    end
```

## Quick Start

```bash
./deploy-all.sh
./test.sh
./cleanup.sh
```

## Configuration

### Round Robin (Default)
```yaml
trafficPolicy:
  loadBalancer:
    simple: ROUND_ROBIN
```

### Random
```yaml
trafficPolicy:
  loadBalancer:
    simple: RANDOM
```

### Least Connections
```yaml
trafficPolicy:
  loadBalancer:
    simple: LEAST_CONN
```

### Consistent Hash (Session Affinity)
```yaml
trafficPolicy:
  loadBalancer:
    consistentHash:
      httpHeaderName: x-user-id   # Hash by header
      # OR
      httpCookie:
        name: session
        ttl: 3600s                # Cookie TTL
      # OR
      useSourceIp: true           # Hash by source IP
```

## Algorithm Comparison

| Algorithm | Best For | Session Affinity |
|-----------|----------|------------------|
| Round Robin | General use | No |
| Random | Stateless apps | No |
| Least Conn | Variable load | No |
| Consistent Hash | Stateful apps | Yes |
