# Rate Limiting — Concept Explained

## 🚰 Real-World Analogy: Water Faucet with a Flow Restrictor

Your building's water system:

- **Without restrictor**: Turn on all faucets → pipes burst, no one gets water 💥
- **With restrictor**: Each faucet limited to 2 gallons/minute → everyone gets steady flow ✅

Rate limiting = a flow restrictor for HTTP requests. Prevents any single user or service from overwhelming your system.

---

## 🎯 The Problem

```
Normal day:     100 requests/minute → Service handles it fine ✅
Attack/spike:   10,000 requests/minute → Service crashes! 💥

Without rate limiting:
  Bot → 10,000 req/min → Your API → DATABASE OVERLOADED → ALL users affected

With rate limiting:
  Bot → 10,000 req/min → Rate Limiter → "Slow down!" (429) → Only 100/min get through
  Other users → still getting served normally ✅
```

---

## 🪣 How It Works: Token Bucket Algorithm

Imagine a bucket that fills with tokens:

```
┌─────────────────────────┐
│  Token Bucket            │
│  ┌─────────────────┐    │
│  │ 🪙🪙🪙🪙🪙        │ ← Bucket has 10 tokens (max)
│  │ 🪙🪙🪙🪙🪙        │
│  └─────────────────┘    │
│                         │
│  Refill: 10 tokens/min  │  ← New tokens added over time
│  Max: 10 tokens          │  ← Bucket can't hold more than 10
└─────────────────────────┘

Request arrives → Have tokens?
  YES → Take 1 token, process request ✅
  NO  → Reject with 429 Too Many Requests ❌
```

### Example timeline:

```
Time 0:00  Bucket: 🪙🪙🪙🪙🪙🪙🪙🪙🪙🪙  (10/10)
  Request 1 → take token → ✅ allowed   (9/10)
  Request 2 → take token → ✅ allowed   (8/10)
  ...
  Request 10 → take token → ✅ allowed  (0/10)
  Request 11 → no tokens → ❌ 429 rejected!

Time 0:06  Bucket refills 1 token:      (1/10)
  Request 12 → take token → ✅ allowed  (0/10)
  Request 13 → no tokens → ❌ 429 rejected!
```

---

## 🔧 Istio Configuration: EnvoyFilter

Rate limiting in Istio uses the **EnvoyFilter** resource to configure Envoy's built-in local rate limiting:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
spec:
  configPatches:
    - applyTo: HTTP_FILTER
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.local_ratelimit
          typed_config:
            stat_prefix: http_local_rate_limiter
            token_bucket:
              max_tokens: 10         # Bucket size
              tokens_per_fill: 10    # How many tokens to add
              fill_interval: 60s     # How often to refill
```

### Breaking down the token bucket config:

| Setting | Value | Meaning |
|---------|-------|---------|
| `max_tokens` | 10 | Maximum burst capacity of the bucket |
| `tokens_per_fill` | 10 | Number of tokens added each interval |
| `fill_interval` | 60s | How often tokens are refilled |

**Result:** Allows 10 requests per minute, with burst capacity of 10.

---

## 🏠 Local vs Global Rate Limiting

### Local Rate Limiting (per-pod)

```
Each pod has its OWN token bucket:

Pod 1: 🪣 10 tokens/min
Pod 2: 🪣 10 tokens/min
Pod 3: 🪣 10 tokens/min

Total capacity: 30 requests/min across all pods
```

**Pros:** Simple, no external service needed
**Cons:** Total rate = per-pod rate × number of pods

### Global Rate Limiting (shared)

```
All pods share ONE token bucket via external service:

Pod 1 ─┐
Pod 2 ──┤── Rate Limit Service (Redis) ── 🪣 10 tokens/min
Pod 3 ─┘

Total capacity: exactly 10 requests/min (regardless of pods)
```

**Pros:** Exact rate control
**Cons:** Needs external rate limit service (Redis)

> **This demo uses Local rate limiting** (simpler to set up).

---

## 🧪 How to Test

```bash
# Send 15 requests quickly (limit is 10/minute)
for i in {1..15}; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Host: httpbin.example.com" $GATEWAY_URL/get)
    echo "Request $i: HTTP $CODE"
done
```

**Expected output:**
```
Request 1:  HTTP 200  ✅ (token taken)
Request 2:  HTTP 200  ✅
...
Request 10: HTTP 200  ✅ (last token)
Request 11: HTTP 429  ❌ (no tokens left!)
Request 12: HTTP 429  ❌
...
Request 15: HTTP 429  ❌
```

**After 60 seconds:** tokens refill, new requests allowed again.

---

## 📈 Production Recommendations

| Scenario | Rate Limit | Why |
|----------|-----------|-----|
| Public API | 100 req/min per user | Prevent abuse |
| Internal API | 1000 req/min per service | Prevent cascading failures |
| Login endpoint | 5 req/min per IP | Prevent brute-force attacks |
| Webhook receiver | 50 req/min total | Protect processing capacity |

---

## 🎓 Key Takeaways

1. **Token bucket** = requests consume tokens; no tokens = rejected (429)
2. **Local rate limit** = per-pod bucket (simple, but total rate scales with pods)
3. **Global rate limit** = shared bucket via external service (exact control)
4. **EnvoyFilter** = how you configure rate limiting in Istio
5. **429 Too Many Requests** = the HTTP status code for rate-limited requests
6. **Protects against**: API abuse, DDoS, cascading failures, brute-force attacks
7. **No code changes** — Envoy handles it at the proxy level
