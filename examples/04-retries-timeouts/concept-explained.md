# Retries & Timeouts — Concept Explained

## 📞 Real-World Analogy: Calling Customer Support

You're calling your bank's customer support:

- **No timeout**: You wait on hold forever... 2 hours later, still waiting 😤
- **With timeout (30s)**: After 30 seconds of ringing, you hang up and try again
- **With retry**: You automatically redial up to 3 times
- **With per-try timeout**: Each call attempt gets 10 seconds max

Istio does exactly this for HTTP requests between your services!

---

## 🎯 The Problem

```
Frontend → Product Service → Database
                ↓
        Sometimes slow (5s)
        Sometimes fails (500)
        Sometimes works (200, 50ms)
```

**Without retries/timeouts:**
- Slow request? Frontend waits forever → user stares at blank screen
- Failed request? User sees "Error 500" → bad experience

**With retries/timeouts:**
- Slow request? Cut off after 3s → show cached result
- Failed request? Auto-retry → user never notices

---

## ⏱️ Two Types of Timeouts

### 1. Overall Timeout (the total budget)

```yaml
timeout: 3s  # Total time for the ENTIRE operation (including retries)
```

```
        |←————————— 3 seconds total ——————————→|
        |                                       |
Start ──┤ Try 1 ──── Try 2 ──── Try 3 ────── TIMEOUT (give up)
```

### 2. Per-Try Timeout (each attempt's limit)

```yaml
retries:
  perTryTimeout: 1s  # Each individual retry gets 1 second
```

```
        |← 1s →|← 1s →|← 1s →|
        |       |       |       |
Start ──┤ Try 1 │ Try 2 │ Try 3 │── All attempts used
        | SLOW! | SLOW! | OK!   |
        | (cut) | (cut) | 200✅ |
```

### How they work together:

```
Overall timeout:  3s
Per-try timeout:  1s
Max retries:      3

Total budget = 3 seconds

Try 1: Takes 1s → timeout! (1s used)
Try 2: Takes 1s → timeout! (2s used)
Try 3: Takes 0.5s → success! (2.5s used, within 3s budget)
```

> **⚠️ Important**: If overall timeout expires, no more retries even if you have attempts left!

---

## 🔄 Retry Logic: When Does Istio Retry?

### What triggers a retry:

```yaml
retries:
  attempts: 3
  retryOn: 5xx,reset,connect-failure,retriable-4xx
```

| Condition | What It Means | Example |
|-----------|---------------|---------|
| `5xx` | Server returned 500, 502, 503, etc. | App crashed |
| `reset` | Connection was reset mid-request | Pod restarted |
| `connect-failure` | Couldn't connect at all | Pod not ready |
| `retriable-4xx` | Specific 4xx errors (409 Conflict) | Race condition |

### What does NOT trigger a retry:

| Response | Retried? | Why |
|----------|----------|-----|
| 200 OK | ❌ | Success! No need |
| 400 Bad Request | ❌ | Client's fault, retrying won't help |
| 404 Not Found | ❌ | Resource doesn't exist |
| 401 Unauthorized | ❌ | Need valid credentials |

---

## 📊 Step-by-Step Scenario

### Configuration:

```yaml
http:
  - timeout: 5s
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx,reset
    route:
      - destination:
          host: product-service
```

### Scenario 1: First attempt succeeds (Happy path)

```
Time: 0ms   → Send request to product-service
Time: 150ms → Response: 200 OK ✅
Total: 150ms, 1 attempt used

Result: Success! Fast and clean.
```

### Scenario 2: First attempt fails, retry succeeds

```
Time: 0ms     → Attempt 1: Send request
Time: 100ms   → Response: 503 (service restarting)
                Envoy: "503 is in retryOn list → RETRY!"
Time: 110ms   → Attempt 2: Send request
Time: 300ms   → Response: 200 OK ✅
Total: 300ms, 2 attempts used

Result: User never saw the error! Transparent recovery.
```

### Scenario 3: Slow + failing (Timeout kicks in)

```
Time: 0ms     → Attempt 1: Send request
Time: 2000ms  → Per-try timeout! (2s limit hit)
                Envoy: "Timeout → RETRY!"
Time: 2010ms  → Attempt 2: Send request
Time: 4010ms  → Per-try timeout! (2s limit hit)
                Envoy: "Timeout → RETRY!"
Time: 4020ms  → Attempt 3: Send request
Time: 5000ms  → ⏰ OVERALL TIMEOUT (5s budget exhausted!)
                Attempt 3 cancelled mid-flight
Total: 5000ms, 3 attempts, all failed

Result: Client gets 504 Gateway Timeout
```

---

## 🎛️ Retry Backoff (Automatic Delay Between Retries)

Istio automatically adds backoff between retries to avoid thundering herd:

```
Attempt 1 fails → wait 25ms
Attempt 2 fails → wait 50ms  (2× longer)
Attempt 3 fails → wait 100ms (2× longer)
```

The base interval is 25ms, doubling each time (exponential backoff). This prevents all retries from hitting the server simultaneously.

---

## ⚠️ Danger: Retry Amplification

Be careful with retries in a deep service chain:

```
Frontend → Service A → Service B → Service C → Database
           3 retries   3 retries   3 retries
```

If the database is down:
- Service C retries 3 times → 3 requests to database
- Service B retries, each causing 3 retries on C → 3 × 3 = 9 requests
- Service A retries, each causing 9 retries → 3 × 9 = 27 requests!

**One user request becomes 27 database requests!** 💥

### Prevention:
1. Only retry at the edge (closest to user)
2. Use short overall timeouts deeper in the chain
3. Combine with circuit breaker to stop cascading retries

---

## 📈 Production vs Demo Values

| Setting | Demo | Production | Why |
|---------|------|-----------|-----|
| timeout | 3-5s | 1-30s | Depends on the service's expected latency |
| attempts | 3 | 2-3 | More retries = more load on failing service |
| perTryTimeout | 1-2s | 200ms-5s | Should be slightly above the service's p99 latency |
| retryOn | 5xx | 5xx,reset,connect-failure | Cover common transient failures |

---

## 🎓 Key Takeaways

1. **Overall timeout** = Total budget for the entire operation (including retries)
2. **Per-try timeout** = Max time for each individual attempt
3. **Retries are transparent** — the client doesn't know a retry happened
4. **Only retry transient errors** — don't retry 400 Bad Request
5. **Watch for amplification** — retries × retries × retries = explosion
6. **Combine with circuit breaker** — circuit breaker prevents retry storms
7. **No code changes** — all configured in the VirtualService YAML
