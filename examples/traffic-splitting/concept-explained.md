# Traffic Splitting (Canary Deployments) — Concept Explained

## 🐤 Real-World Analogy: Introducing a New Menu Item

You own a restaurant chain with 100 locations:

- **Current menu** (v1): Proven dishes that customers love
- **New dish** (v2): A new recipe you want to test

**Bad strategy:** Replace the entire menu nationwide → If customers hate it, you lose all revenue! 💥
**Smart strategy (Canary):** Serve the new dish at 20 locations first → If it works, expand to 100 gradually ✅

Traffic splitting works the same way:
- Send **80% of requests to v1** (safe, proven)
- Send **20% of requests to v2** (testing the new version)

---

## 🎯 The Problem: Deploying New Versions

### Without traffic splitting:

```
Before deploy:  100% traffic → v1 ✅

After deploy:   100% traffic → v2 ???
                v2 has a bug → 100% of users affected! 💥
```

### With traffic splitting:

```
Step 1:  80% → v1,  20% → v2   (test with small traffic)
Step 2:  50% → v1,  50% → v2   (looks good, increase)
Step 3:  20% → v1,  80% → v2   (almost there)
Step 4:   0% → v1, 100% → v2   (full rollout!)

If v2 breaks at any step → instantly revert to 100% v1 ✅
```

---

## ⚙️ How Traffic Splitting Works

```
                           ┌──────────────┐
                      80%  │  v1 (stable) │  3 replicas
                    ┌─────▶│  weight: 80  │
                    │      └──────────────┘
┌─────────┐   ┌────┴────┐
│ Client   │──▶│ Envoy   │  Rolls a weighted dice:
│          │   │ Proxy   │  0-79  → v1 (80% chance)
└─────────┘   └────┬────┘  80-99 → v2 (20% chance)
                    │      ┌──────────────┐
                    └─────▶│  v2 (canary) │  1 replica
                      20%  │  weight: 20  │
                           └──────────────┘
```

---

## 🔧 Configuration

### VirtualService (The Traffic Split):

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  http:
    - route:
        - destination:
            host: reviews-svc
            subset: v1
          weight: 80          # 80% of traffic
        - destination:
            host: reviews-svc
            subset: v2
          weight: 20          # 20% of traffic
```

> **⚠️ Weights must add up to 100!**

### DestinationRule (The Subsets):

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
spec:
  host: reviews-svc
  subsets:
    - name: v1
      labels:
        version: v1    # Pods with label version=v1
    - name: v2
      labels:
        version: v2    # Pods with label version=v2
```

---

## 📊 What the Traffic Looks Like

Sending 20 requests with 80/20 split:

```
Request  1: v1  ─┐
Request  2: v1   │
Request  3: v1   │
Request  4: v2  ─┤─── v2 (canary)
Request  5: v1   │
Request  6: v1   │
Request  7: v1   │
Request  8: v1   │
Request  9: v2  ─┤─── v2 (canary)
Request 10: v1   │
Request 11: v1   │
Request 12: v2  ─┤─── v2 (canary)
Request 13: v1   │
Request 14: v1   │
Request 15: v1   │
Request 16: v1   │
Request 17: v2  ─┤─── v2 (canary)
Request 18: v1   │
Request 19: v1   │
Request 20: v1  ─┘

Result: v1 got 16 (80%), v2 got 4 (20%) ✅
```

> **Note:** These are probabilistic — small samples may deviate. Over many requests, it converges to 80/20.

---

## 🚀 Gradual Rollout Strategy

```
Day 1:  weight: 95 (v1) / weight: 5  (v2)   "Smoke test with 5%"
          ↓ monitor metrics → all good ✅
Day 2:  weight: 80 (v1) / weight: 20 (v2)   "Expand to 20%"
          ↓ monitor metrics → all good ✅
Day 3:  weight: 50 (v1) / weight: 50 (v2)   "50/50 split"
          ↓ monitor metrics → all good ✅
Day 4:  weight: 0  (v1) / weight: 100 (v2)  "Full rollout!"
```

### What to monitor at each step:
- ✅ Error rate (is v2 returning more errors?)
- ✅ Latency (is v2 slower?)
- ✅ CPU/memory usage (is v2 using more resources?)
- ✅ Business metrics (are users still buying/clicking/engaging?)

### If something goes wrong:

```yaml
# Instant rollback — just change the weights!
- destination:
    subset: v1
  weight: 100    # 100% back to stable
- destination:
    subset: v2
  weight: 0      # 0% to broken version
```

---

## 🆚 Traffic Splitting vs Request Routing

| Feature | Traffic Splitting | Request Routing |
|---------|------------------|-----------------|
| **How it decides** | Random percentage (80/20) | Based on header values |
| **Who gets v2** | Random users | Specific users (beta, internal) |
| **Use case** | Gradual rollout | Feature flags, A/B testing |
| **User control** | No (random) | Yes (header-based) |

**Combine both** for advanced strategies:
```yaml
# Internal team gets v2 (100%), everyone else gets 80/20 split
- match:
    - headers:
        x-user-type:
          exact: internal
  route:
    - destination:
        subset: v2
      weight: 100

- route:
    - destination:
        subset: v1
      weight: 80
    - destination:
        subset: v2
      weight: 20
```

---

## 🧪 Testing

```bash
# Send 20 requests and count distribution
V1=0; V2=0
for i in {1..20}; do
    RESPONSE=$(curl -s -H "Host: reviews.example.com" $GATEWAY_URL/version)
    if [[ "$RESPONSE" == *"v1"* ]]; then ((V1++)); fi
    if [[ "$RESPONSE" == *"v2"* ]]; then ((V2++)); fi
done
echo "v1: $V1 ($(( V1*100/20 ))%) | v2: $V2 ($(( V2*100/20 ))%)"
# Expected: v1: ~16 (80%) | v2: ~4 (20%)
```

---

## 🎓 Key Takeaways

1. **Weight-based routing** — percentage of traffic goes to each version
2. **Weights must add to 100** — v1: 80 + v2: 20 = 100
3. **Gradual rollout** — start small (5%), increase if metrics look good
4. **Instant rollback** — change weights to 100/0 to revert
5. **Probabilistic** — small samples may vary, large samples converge
6. **Combines with monitoring** — watch error rate, latency, business metrics
7. **No code changes** — just update the VirtualService weights
