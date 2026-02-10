# Fault Injection — Concept Explained

## 💉 Real-World Analogy: Fire Drill

Think of a fire drill at your office:

- **No actual fire** — everything is safe
- **Simulates an emergency** — tests how people react
- **Finds problems** — "Oh, that exit door is locked!"
- **Makes you prepared** — when a real fire happens, you know what to do

Istio's fault injection is a **fire drill for your microservices!** You inject fake failures to test how your system handles real ones.

---

## 🎯 The Problem Without Fault Injection

How do you test if your app handles failures?

**Option 1: Wait for real failures** 😰
- Unpredictable, happens at 3am, users are affected

**Option 2: Kill services manually** 😬
- Disruptive, hard to control, can't easily repeat

**Option 3: Modify application code** 😵
- Time-consuming, risky, need to remove test code later

**Option 4: Istio Fault Injection** ✅
- No code changes
- Controlled (exact percentage + duration)
- Repeatable (just apply a YAML file)
- Safe (remove YAML to stop)

---

## 📦 Two Types of Faults

### Type 1: DELAY (Slow Response)

```
Normal:
  Client → Envoy → httpbin → Response (20ms)

With 5s Delay:
  Client → Envoy → [WAIT 5 SECONDS] → httpbin → Response (5020ms)
```

**What it simulates:** Database slow, network congestion, overloaded API

**Real example:** Your payment service takes 5s instead of 200ms. Does the checkout page show a loading spinner? Or does it just freeze?

### Type 2: ABORT (Error Response)

```
Normal:
  Client → Envoy → httpbin → 200 OK

With Abort:
  Client → Envoy → 503 Error (httpbin is NEVER called!)
```

**What it simulates:** Service crash, network failure, dependency down

**Real example:** The recommendation service is down. Does the product page still load (without recommendations)? Or does the entire page crash?

---

## ⚙️ How It Works Inside Envoy

```
┌──────────┐    ┌──────────────────────────────────┐    ┌──────────┐
│  Client   │───▶│    Envoy Sidecar Proxy           │───▶│  httpbin  │
│ (curl)    │    │                                  │    │  pod      │
└──────────┘    │  For EACH request:                │    └──────────┘
                │                                  │
                │  1. Check ABORT rules             │
                │     Roll dice → 50% chance?       │
                │     YES → Return 503 immediately  │
                │           (httpbin never called!)  │
                │     NO  → Continue to step 2      │
                │                                  │
                │  2. Check DELAY rules             │
                │     Roll dice → 50% chance?       │
                │     YES → Sleep 5s, then forward  │
                │     NO  → Forward immediately     │
                └──────────────────────────────────┘
```

> **Key insight**: Abort is checked **FIRST**. If a request is aborted, it never reaches the delay check or the backend pod.

---

## 🎲 Percentage — How the "Dice Roll" Works

```yaml
percentage:
  value: 50  # 50% of requests are affected
```

This is evaluated **per-request**, not per-connection:

```
Request 1 → Roll dice → 73 (> 50) → NO fault
Request 2 → Roll dice → 12 (< 50) → FAULT APPLIED
Request 3 → Roll dice → 88 (> 50) → NO fault
Request 4 → Roll dice → 31 (< 50) → FAULT APPLIED
```

Over many requests, you'll see approximately 50% affected. But small samples can vary widely!

---

## 🔀 Combined Faults: Delay + Abort Together

When BOTH are configured:

```yaml
fault:
  abort:
    percentage:
      value: 20    # 20% of ALL requests
    httpStatus: 503
  delay:
    percentage:
      value: 30    # 30% of NON-ABORTED requests
    fixedDelay: 3s
```

### Decision tree for each request:

```
Request arrives
     │
     ▼
  Abort check (20% chance)
     │
  ┌──┴──┐
  │ YES │ → Return 503 immediately. DONE.
  │ (20%)│
  └─────┘
  │ NO (80%) │
  └──────────┘
     │
     ▼
  Delay check (30% chance of the remaining 80%)
     │
  ┌──┴──┐
  │ YES │ → Wait 3s, then forward to httpbin → 200 OK
  │ (24%)│   (30% of 80% = 24% of all requests)
  └─────┘
  │ NO (56%) │
  └──────────┘
     │
     ▼
  Forward immediately → 200 OK (fast)
```

**Final distribution for 100 requests:**

| Outcome | Count | Description |
|---------|-------|-------------|
| 503 (fast) | ~20 | Aborted immediately |
| 200 (slow ~3s) | ~24 | Delayed then forwarded |
| 200 (fast) | ~56 | No fault applied |

---

## ⚠️ Common Mistake: Multiple VirtualServices

If you apply ALL fault files at once:

```bash
# ❌ WRONG — creates 3 VirtualServices for the same host
kubectl apply -f fault-delay.yaml
kubectl apply -f fault-abort.yaml
kubectl apply -f fault-combined.yaml
```

Result: Istio sees 3 VirtualServices targeting `httpbin` → **undefined behavior** (random 503s, no faults applied, chaos!)

```bash
# ✅ CORRECT — only one at a time
kubectl delete vs httpbin-delay httpbin-abort httpbin-combined -n fault-demo
kubectl apply -f fault-delay.yaml   # Apply ONE
```

---

## 🧪 How to Test Each Scenario

### Delay test:
```bash
# Apply delay fault
kubectl apply -f fault-delay.yaml

# Send requests — some should take ~5s
for i in {1..6}; do
    START=$(date +%s%N)
    curl -s -o /dev/null -H "Host: httpbin.example.com" $GATEWAY_URL/get
    END=$(date +%s%N)
    echo "Request $i: $(( (END-START)/1000000 ))ms"
done
```

Expected output:
```
Request 1: 5021ms  ← DELAYED
Request 2: 18ms
Request 3: 5019ms  ← DELAYED
Request 4: 17ms
Request 5: 5024ms  ← DELAYED
Request 6: 19ms
```

### Abort test:
```bash
# Switch to abort fault
kubectl delete vs httpbin-delay -n fault-demo
kubectl apply -f fault-abort.yaml

# Send requests — some should return 503
for i in {1..6}; do
    curl -s -o /dev/null -w "Request $i: HTTP %{http_code}\n" \
        -H "Host: httpbin.example.com" $GATEWAY_URL/get
done
```

Expected output:
```
Request 1: HTTP 200
Request 2: HTTP 503  ← ABORTED
Request 3: HTTP 503  ← ABORTED
Request 4: HTTP 200
Request 5: HTTP 200
Request 6: HTTP 503  ← ABORTED
```

---

## 🎓 Key Takeaways

1. **Delay** = "Make it slow" — tests timeout handling, loading states, retry logic
2. **Abort** = "Make it fail" — tests error handling, fallbacks, circuit breakers
3. **Combined** = real-world simulation where services are both slow AND failing
4. **Percentage** = controls what fraction of requests are affected (per-request dice roll)
5. **Abort before delay** = if request is aborted, delay is skipped
6. **One VirtualService at a time** — never have multiple fault VS for the same host
7. **No code changes** — faults are injected at the Envoy proxy level
