# Traffic Mirroring — Concept Explained

## 🪞 Real-World Analogy: Security Camera Footage

Imagine a bank:

- **Live tellers** serve real customers (production)
- **Security cameras** record everything (mirror)
- Cameras **don't interfere** with transactions — customers don't even know
- Bank uses recordings to **train new tellers** or **detect fraud**

Traffic mirroring is the security camera for your microservices!

---

## 🎯 The Problem: Testing in Production

You've built a new version of your payment service (v2). How do you test it?

**Option 1: Test in staging** 😬
- Staging ≠ production (different data, different load, different scale)
- "Works in staging, broken in production" — classic problem

**Option 2: Canary deploy** 😰
- Send 5% of REAL users to v2
- If v2 is broken → 5% of users are affected!

**Option 3: Traffic Mirroring** ✅
- Send 100% of traffic to v1 (production, users get this)
- **Copy** 100% of traffic to v2 (shadow, nobody sees this)
- v2's response is **thrown away** — users ONLY see v1's response
- If v2 crashes → **zero user impact!**

---

## ⚙️ How It Works

```
                    ┌──────────────┐
               ┌───▶│   v1 (prod)  │───▶ Response to user ✅
               │    └──────────────┘
┌─────────┐   ┌┴────────┐
│ Client   │──▶│ Envoy   │
│ (user)   │   │ Proxy   │
└─────────┘   └┬────────┘
               │    ┌──────────────┐
               └───▶│ v2 (shadow)  │───▶ Response DISCARDED 🗑️
                    └──────────────┘

User ONLY sees v1's response.
v2 processes the same request but its response is thrown away.
```

---

## 🔍 Step-by-Step: What Happens

### 1. User sends request

```
User → curl http://myapp.com/api/checkout
```

### 2. Envoy receives the request

```
Envoy receives: POST /api/checkout
  Body: { "item": "laptop", "card": "****1234" }
```

### 3. Envoy forwards to v1 (PRIMARY)

```
Request → v1 (production)
v1 processes it → returns 200 OK, { "order": "ORD-123" }
Envoy sends this response to the user ✅
```

### 4. Envoy COPIES the request to v2 (MIRROR)

```
Copied request → v2 (shadow)
v2 processes it → returns 200 OK, { "order": "ORD-456" }
Envoy THROWS AWAY v2's response 🗑️
```

### 5. User gets v1's response

```
User sees: 200 OK, { "order": "ORD-123" }
(v2's response is completely ignored)
```

---

## ⚠️ Important Details

### The mirrored request is "fire-and-forget"

```
Primary (v1):                    Mirror (v2):
─────────────                    ────────────
• Response sent to client        • Response DISCARDED
• Errors affect the user         • Errors are INVISIBLE to user
• Latency matters                • Latency doesn't matter
• Must be reliable               • Can crash safely
```

### The Host header is modified

Istio adds a `-shadow` suffix to the Host header for mirrored requests:

```
Primary request:   Host: httpbin
Mirrored request:  Host: httpbin-shadow
```

This helps you identify mirrored traffic in v2's logs.

---

## 📊 Use Cases

| Use Case | How Mirroring Helps |
|----------|-------------------|
| **New version testing** | Send production traffic to v2, compare responses offline |
| **Performance testing** | See if v2 handles real load without risking users |
| **Data pipeline testing** | Verify v2 processes data correctly before switching |
| **Security auditing** | Shadow copy for security analysis without slowing production |
| **ML model testing** | Compare v2 model predictions against v1 with real data |

---

## 🔧 Configuration

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
spec:
  http:
    - route:
        - destination:
            host: httpbin
            subset: v1
          weight: 100      # ALL traffic goes to v1
      mirror:
        host: httpbin
        subset: v2         # COPY traffic to v2
      mirrorPercentage:
        value: 100.0       # Mirror 100% of requests
```

| Setting | What It Does |
|---------|-------------|
| `route → v1, weight: 100` | All real traffic goes to v1 |
| `mirror → v2` | Copy requests to v2 |
| `mirrorPercentage: 100` | Mirror every request (use 50 for half) |

---

## 🆚 Mirroring vs Canary vs Blue-Green

| Strategy | User Impact | Risk | Real Traffic? |
|----------|-------------|------|--------------|
| **Mirroring** | None (v2 response discarded) | Zero | Yes (copied) |
| **Canary** | 5-10% users see v2 | Low | Yes (real) |
| **Blue-Green** | All users switch at once | Medium | Yes (real) |

Mirroring is the safest way to test with production traffic!

---

## 🎓 Key Takeaways

1. **Zero risk** — mirrored traffic responses are discarded
2. **Real production traffic** — not synthetic tests, actual user patterns
3. **Fire-and-forget** — mirror failures don't affect users
4. **Host header `-shadow`** — lets you distinguish mirror traffic in logs
5. **Use before canary** — validate v2 with mirroring first, then canary
6. **No code changes** — configured entirely in VirtualService YAML
