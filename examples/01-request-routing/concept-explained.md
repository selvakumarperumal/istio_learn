# Request Routing — Concept Explained

## 🚦 Real-World Analogy: Airport Check-In Counters

Imagine an airport with 3 check-in counters for the same airline:

- **Counter 1** (v1): Regular passengers
- **Counter 2** (v2): Business class passengers
- **Counter 3** (v3): Staff/internal passengers

A sign at the entrance says:
- "If your ticket says **BUSINESS** → go to Counter 2"
- "If your badge says **STAFF** → go to Counter 3"
- "Everyone else → go to Counter 1"

Istio's request routing works exactly like this, but with **HTTP headers** instead of tickets!

---

## 🎯 The Problem Without Request Routing

Without Istio, Kubernetes Service does simple round-robin:

```
Request 1 → v1
Request 2 → v2
Request 3 → v3
Request 4 → v1 (repeat)
```

Every user hits random versions — you can't:
- ❌ Test v2 with only beta users
- ❌ Keep production users on stable v1
- ❌ Route internal debugging traffic to v3

---

## ✅ With Istio Request Routing

```
                         ┌──────────────┐
                    ┌───▶│ reviews-v1   │  (stable)
                    │    └──────────────┘
┌─────────┐   ┌────┴────┐
│ Client   │──▶│ Envoy   │  Checks headers:
│ (curl)   │   │ Proxy   │  x-user-type: beta → v2
└─────────┘   └────┬────┘  x-user-type: internal → v3
                    │       no header → v1
                    │    ┌──────────────┐
                    ├───▶│ reviews-v2   │  (beta features)
                    │    └──────────────┘
                    │    ┌──────────────┐
                    └───▶│ reviews-v3   │  (internal/debug)
                         └──────────────┘
```

---

## 🧩 How the Pieces Fit Together

There are **5 Kubernetes/Istio resources** involved. Here's how they connect:

```
┌─────────────────────────────────────────────────────────┐
│ 1. GATEWAY                                              │
│    "Accept HTTP traffic for reviews.example.com"        │
│    Listens on port 80 of the Istio Ingress Gateway      │
└──────────────────────┬──────────────────────────────────┘
                       │ routes to
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 2. VIRTUALSERVICE                                       │
│    "Route based on x-user-type header"                  │
│    Rule 1: header=beta → subset v2                      │
│    Rule 2: header=internal → subset v3                  │
│    Rule 3: (default) → subset v1                        │
└──────────────────────┬──────────────────────────────────┘
                       │ uses subsets from
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 3. DESTINATION RULE                                     │
│    Defines subsets:                                      │
│    v1 = pods with label version=v1                      │
│    v2 = pods with label version=v2                      │
│    v3 = pods with label version=v3                      │
└──────────────────────┬──────────────────────────────────┘
                       │ targets pods via
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 4. SERVICE (reviews-svc)                                │
│    Selector: app=reviews (matches ALL versions)         │
│    Provides DNS name + port mapping                     │
└──────────────────────┬──────────────────────────────────┘
                       │ selects
                       ▼
┌─────────────────────────────────────────────────────────┐
│ 5. DEPLOYMENTS (3 separate)                             │
│    reviews-v1: labels {app: reviews, version: v1}       │
│    reviews-v2: labels {app: reviews, version: v2}       │
│    reviews-v3: labels {app: reviews, version: v3}       │
└─────────────────────────────────────────────────────────┘
```

---

## 🔍 Step-by-Step: What Happens When a Request Arrives

### Scenario 1: Beta user request

```bash
curl -H "Host: reviews.example.com" \
     -H "x-user-type: beta" \
     http://$GATEWAY_URL/reviews
```

```
Step 1: Request hits Istio Ingress Gateway (port 80)
Step 2: Gateway matches Host: reviews.example.com → accept
Step 3: VirtualService checks rules IN ORDER:
        Rule 1: Does header "x-user-type" == "beta"?
        → YES! Route to destination: reviews-svc, subset: v2
Step 4: DestinationRule says subset "v2" = pods with version=v2
Step 5: Request goes to reviews-v2 pod
Step 6: Response: "reviews-v2" ✅
```

### Scenario 2: No header (regular user)

```bash
curl -H "Host: reviews.example.com" http://$GATEWAY_URL/reviews
```

```
Step 1: Request hits Istio Ingress Gateway
Step 2: Gateway matches host → accept
Step 3: VirtualService checks rules IN ORDER:
        Rule 1: header "x-user-type" == "beta"? → NO
        Rule 2: header "x-user-type" == "internal"? → NO
        Rule 3: No conditions (default catch-all)
        → Route to subset: v1
Step 4: Request goes to reviews-v1 pod
Step 5: Response: "reviews-v1" ✅
```

---

## ⚠️ Important: Rule Evaluation Order

VirtualService rules are evaluated **top to bottom, first match wins**:

```yaml
http:
  - match:                    # Rule 1 (checked FIRST)
      - headers:
          x-user-type:
            exact: beta
    route:
      - destination:
          subset: v2

  - match:                    # Rule 2 (checked SECOND)
      - headers:
          x-user-type:
            exact: internal
    route:
      - destination:
          subset: v3

  - route:                    # Rule 3 (DEFAULT — no match block)
      - destination:
          subset: v1
```

> **⚠️ Always put the default (no match) rule LAST!** If you put it first, it catches everything and the other rules never execute.

---

## 🏷️ The Labeling System

Labels are the glue that connects everything:

```
Pod labels:
  reviews-v1 pod → app: reviews, version: v1
  reviews-v2 pod → app: reviews, version: v2
  reviews-v3 pod → app: reviews, version: v3

Service selector:
  app: reviews → selects ALL 3 pods

DestinationRule subsets:
  subset "v1" → version: v1 → only reviews-v1 pod
  subset "v2" → version: v2 → only reviews-v2 pod
  subset "v3" → version: v3 → only reviews-v3 pod
```

**Two-level filtering:**
1. Service says "I know about ALL pods with `app: reviews`"
2. DestinationRule says "Within those, `v1` means only `version: v1` pods"

---

## 🆚 Gateway vs Kubernetes Ingress

| Feature | Kubernetes Ingress | Istio Gateway |
|---------|-------------------|---------------|
| Header-based routing | ❌ Not supported | ✅ Full support |
| Traffic splitting | ❌ Not supported | ✅ Weight-based |
| Fault injection | ❌ Not supported | ✅ Delay/abort |
| Retries/timeouts | ❌ Not supported | ✅ Configurable |
| mTLS | ❌ Manual setup | ✅ Automatic |
| Scope | Ingress only | Ingress + mesh internal |

---

## 🧪 Testing Commands

```bash
# Test v1 (default — no header)
curl -H "Host: reviews.example.com" http://$GATEWAY_URL/reviews
# Expected: response from v1

# Test v2 (beta users)
curl -H "Host: reviews.example.com" \
     -H "x-user-type: beta" \
     http://$GATEWAY_URL/reviews
# Expected: response from v2

# Test v3 (internal users)
curl -H "Host: reviews.example.com" \
     -H "x-user-type: internal" \
     http://$GATEWAY_URL/reviews
# Expected: response from v3
```

---

## 🎓 Key Takeaways

1. **VirtualService** = The routing rules (which version gets which traffic)
2. **DestinationRule** = Defines the subsets (v1, v2, v3) using pod labels
3. **Gateway** = The front door (accepts external traffic)
4. **Service** = DNS name for all versions (Istio overrides its routing)
5. **Headers** = The "ticket" that decides which counter you go to
6. **Order matters** — rules are evaluated top-to-bottom, first match wins
7. **Default rule goes last** — always put the catch-all at the bottom
