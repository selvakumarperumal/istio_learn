# Load Balancing — Concept Explained

## 🍕 Real-World Analogy: Pizza Delivery

You run a pizza shop with 4 delivery drivers:

- **Round Robin** = Give orders to drivers in order: Driver 1, 2, 3, 4, 1, 2, 3, 4...
- **Random** = Pick a random driver for each order
- **Least Connections** = Give the order to whichever driver has the fewest deliveries right now
- **Consistent Hash** = Same customer always gets the same driver (they know the address already!)

---

## 🎯 The Problem

You have 3 replicas of a service. How should traffic be distributed?

```
         ┌──────────────┐
    ????─▶│ httpbin-1    │ (CPU: 10%)
         └──────────────┘
         ┌──────────────┐
    ????─▶│ httpbin-2    │ (CPU: 90% 🔥)
         └──────────────┘
         ┌──────────────┐
    ????─▶│ httpbin-3    │ (CPU: 50%)
         └──────────────┘
```

**Default (Round Robin)** sends equal traffic to each — even if httpbin-2 is struggling!

---

## 📊 The Four Algorithms Explained

### 1. ROUND_ROBIN (Default)

```
Request 1 → Pod 1
Request 2 → Pod 2
Request 3 → Pod 3
Request 4 → Pod 1  (start over)
Request 5 → Pod 2
Request 6 → Pod 3
```

**Pros:** Simple, predictable, equal distribution
**Cons:** Ignores pod health — keeps sending to slow pods
**Best for:** Stateless services with similar performance

```yaml
trafficPolicy:
  loadBalancer:
    simple: ROUND_ROBIN
```

---

### 2. RANDOM

```
Request 1 → Pod 3
Request 2 → Pod 1
Request 3 → Pod 3  (random can repeat!)
Request 4 → Pod 2
Request 5 → Pod 1
Request 6 → Pod 3
```

**Pros:** Good distribution over time, no state needed
**Cons:** Short-term imbalance possible (Pod 3 got 3 out of 6)
**Best for:** Large number of pods where randomness evens out

```yaml
trafficPolicy:
  loadBalancer:
    simple: RANDOM
```

---

### 3. LEAST_CONN (Least Connections)

```
Current state:
  Pod 1: 2 active connections
  Pod 2: 5 active connections
  Pod 3: 1 active connection  ← fewest!

New request → Pod 3 (least connections)

After:
  Pod 1: 2 active connections
  Pod 2: 5 active connections
  Pod 3: 2 active connections
```

**Pros:** Automatically adapts to slow pods (they accumulate connections)
**Cons:** Slightly more CPU (needs to track connection counts)
**Best for:** Services with varying response times

```yaml
trafficPolicy:
  loadBalancer:
    simple: LEAST_CONN
```

#### Why it's smart:

```
Slow Pod (1s response):     Fast Pod (100ms response):
  └─ Connection stays 1s     └─ Connection freed in 100ms
  └─ Accumulates more        └─ Available for new requests
  └─ Gets FEWER new requests  └─ Gets MORE new requests
  = Self-balancing!
```

---

### 4. CONSISTENT_HASH (Session Affinity)

Same user/request always goes to the same pod:

```
User "alice" → hash("alice") → Pod 2 (always)
User "bob"   → hash("bob")   → Pod 1 (always)
User "charlie" → hash("charlie") → Pod 3 (always)
```

**Pros:** Session affinity, great for caching
**Cons:** Can cause imbalance if one user sends lots of traffic
**Best for:** Services that cache per-user data in memory

```yaml
trafficPolicy:
  loadBalancer:
    consistentHash:
      httpHeaderName: x-user-id  # Hash based on this header
```

#### Hash options:

| Hash By | Config | Use Case |
|---------|--------|----------|
| HTTP header | `httpHeaderName: x-user-id` | User-specific caching |
| Cookie | `httpCookie: { name: session }` | Session sticky |
| Source IP | `useSourceIp: true` | Client-specific routing |

---

## 🔍 Visual Comparison

Imagine 12 requests to 3 pods:

```
ROUND_ROBIN:     Pod1: ████  Pod2: ████  Pod3: ████  (perfectly even)

RANDOM:          Pod1: ███   Pod2: █████ Pod3: ████  (roughly even)

LEAST_CONN:      Pod1: ████  Pod2: ██    Pod3: ██████
                 (varies — fewer to slow pods, more to fast pods)

CONSISTENT_HASH: Pod1: ██████████ Pod2: █  Pod3: █
                 (depends on hash distribution — can be uneven!)
```

---

## 📈 Production Recommendations

| Scenario | Recommended Algorithm | Why |
|----------|----------------------|-----|
| Generic microservice | ROUND_ROBIN | Simple, works well |
| Varying response times | LEAST_CONN | Adapts to slow pods |
| User-specific caching | CONSISTENT_HASH | Same user → same pod |
| Many replicas (>10) | RANDOM | Statistically good distribution |
| Stateless + equal pods | ROUND_ROBIN | Default is fine |

---

## 🎓 Key Takeaways

1. **Round Robin** = "Take turns equally" — simple and predictable
2. **Random** = "Pick anyone" — good enough for large pools
3. **Least Connections** = "Give it to the least busy" — smartest for mixed workloads
4. **Consistent Hash** = "Same user, same pod" — best for session affinity
5. **Default is Round Robin** — you don't need to change this for most services
6. **Configured in DestinationRule** — not VirtualService!
