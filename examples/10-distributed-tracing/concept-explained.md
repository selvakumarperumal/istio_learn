# Distributed Tracing — Concept Explained

## 🔍 Real-World Analogy: Package Tracking

When you order from Amazon:

1. **Order placed** → timestamp: 10:00 AM
2. **Picked from shelf** → warehouse, 10:05 AM
3. **Loaded on truck** → distribution center, 10:30 AM
4. **Out for delivery** → local hub, 2:00 PM
5. **Delivered** → your door, 4:00 PM

Each step has a **timestamp** and **location**. If your package is late, you check the tracking to find the bottleneck.

Distributed tracing does the same for HTTP requests flowing through microservices!

---

## 🎯 The Problem

Your app has 5 microservices. A user request takes 10 seconds. WHERE is the slowdown?

```
User → Frontend → Product → Inventory → Pricing → Database
       (fast)     (fast)    (SLOW??)   (fast)    (SLOW??)
```

**Without tracing:** "Something is slow. No idea what." 🤷
**With tracing:** "Inventory service took 7.2 seconds on line 42." 🎯

---

## 📊 What a Trace Looks Like

```
Trace ID: abc-123-def
├── Frontend         [──────────────────────────────────] 10.0s
│   ├── Product      [───────]                            2.1s
│   │   └── Database [──]                                 0.8s
│   ├── Inventory    [─────────────────────]               7.2s  ← BOTTLENECK!
│   └── Pricing      [──]                                  0.3s

Timeline: 0s ────────────────────────────────────────── 10s
```

Each bar is a **span** (one service's work). All spans share a **trace ID**.

---

## ⚙️ How It Works in Istio

### The Magic: Envoy does most of the work automatically!

```
┌──────────────────────────────────────────────────────────────┐
│ Frontend Pod                                                  │
│ ┌────────────┐    ┌──────────────────────────────┐           │
│ │ Your App   │───▶│ Envoy Sidecar                │───▶ Next  │
│ │            │    │                              │    Service│
│ │ Must pass  │    │ Automatically:               │           │
│ │ headers!   │    │ 1. Records start/end time    │           │
│ │ (see below)│    │ 2. Records HTTP status       │           │
│ └────────────┘    │ 3. Sends span to Jaeger      │           │
│                   └──────────────────────────────┘           │
└──────────────────────────────────────────────────────────────┘
```

### Critical: Your App MUST Forward These Headers

Envoy generates trace headers, but your app **must forward them** to downstream services:

```
Headers that MUST be propagated:
  x-request-id          ← Unique request identifier
  x-b3-traceid          ← Trace ID (links all spans)
  x-b3-spanid           ← Current span ID
  x-b3-parentspanid     ← Parent span ID
  x-b3-sampled          ← Whether to sample this trace
  x-b3-flags            ← Debug flags
  traceparent           ← W3C trace context (newer standard)
  tracestate            ← W3C trace state
```

### What happens if you DON'T forward headers:

```
WITH header propagation:
  Frontend [span1] → Product [span2] → Database [span3]
  All linked by trace ID "abc-123" → ONE complete trace ✅

WITHOUT header propagation:
  Frontend [span1]      → trace "abc-123"
  Product [span2]       → trace "xyz-789" (NEW trace!)
  Database [span3]      → trace "mno-456" (NEW trace!)
  Three DISCONNECTED traces ❌
```

---

## 🖥️ Jaeger UI: Reading Traces

After generating traffic, open Jaeger:

```bash
istioctl dashboard jaeger
```

### What you see:

```
┌─────────────────────────────────────────────────────┐
│ Jaeger UI                                            │
│                                                      │
│ Service: frontend ▼   Operation: all ▼   Find Traces│
│                                                      │
│ ┌─────────────────────────────────────────────────┐ │
│ │ Trace: abc-123  (5 spans, 10.2s)                 │ │
│ │ ├── frontend GET /page         [████████████] 10s│ │
│ │ │   ├── product GET /info      [███]          2s │ │
│ │ │   ├── inventory GET /stock   [████████]     7s │ │◀── SLOW!
│ │ │   └── pricing GET /price     [█]          0.3s │ │
│ │ └────────────────────────────────────────────────│ │
│ └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

Click on the slow span to see:
- Start time, duration
- HTTP method, URL, status code
- Pod name, namespace
- Tags and logs

---

## 📈 Sampling Rate

Not every request is traced (too much data). Istio samples a percentage:

```yaml
# In Istio's mesh config:
defaultConfig:
  tracing:
    sampling: 1.0   # 1% of requests (production)
    # sampling: 100.0  # 100% of requests (demo)
```

| Sampling Rate | When to Use |
|---------------|-------------|
| 100% | Development/demo |
| 1-5% | Production (low traffic) |
| 0.1% | Production (high traffic) |

---

## 🎓 Key Takeaways

1. **Trace** = complete journey of a request across services
2. **Span** = one service's contribution to the trace
3. **Trace ID** = links all spans together (like a package tracking number)
4. **Header propagation is YOUR responsibility** — Envoy can't do this automatically
5. **Jaeger** = UI for viewing traces and finding bottlenecks
6. **Sampling** = controls what percentage of requests are traced
7. **Envoy does the span creation** — no tracing library needed in your app
