# Metrics & Prometheus — Concept Explained

## 📊 Real-World Analogy: Car Dashboard

Your car's dashboard shows:

- **Speedometer** → current speed (like request rate)
- **Temperature gauge** → engine heat (like CPU usage)
- **Fuel gauge** → remaining fuel (like memory usage)
- **Check engine light** → something's wrong (like error rate spike)

Without a dashboard, you'd drive blind. Without metrics, your microservices are invisible!

---

## 🎯 The Problem

You have 20 microservices running in Kubernetes. How do you answer:

- "How many requests per second is the checkout service handling?"
- "What's the 99th percentile latency of payments?"
- "Did the error rate spike after the last deployment?"
- "Which service is consuming the most CPU?"

**Without metrics:** "I have no idea. Let me check the logs." (too slow!)
**With Prometheus + Grafana:** Real-time dashboards with instant answers!

---

## ⚙️ How Istio Metrics Work

### Envoy sidecars generate metrics automatically:

```
┌──────────────────────────────────────────────────┐
│ Every Pod                                         │
│ ┌────────────┐    ┌──────────────────┐           │
│ │ Your App   │───▶│ Envoy Sidecar    │           │
│ │ (no code   │    │                  │           │
│ │  changes!) │    │ Records for      │           │
│ └────────────┘    │ EVERY request:   │           │
│                   │ • Response time  │           │
│                   │ • Status code    │           │
│                   │ • Request size   │           │
│                   │ • Upstream host  │           │
│                   │ • TCP connections│           │
│                   └────────┬─────────┘           │
│                            │ :15020/stats/prometheus │
└────────────────────────────┼─────────────────────┘
                             │
                             ▼
                   ┌──────────────────┐
                   │  Prometheus      │  Scrapes metrics
                   │  (Time-series DB)│  every 15 seconds
                   └────────┬─────────┘
                            │
                            ▼
                   ┌──────────────────┐
                   │  Grafana         │  Visualizes as
                   │  (Dashboard UI)  │  graphs & alerts
                   └──────────────────┘
```

---

## 📋 Key Metrics Istio Generates

### Request Metrics:

| Metric | What It Measures | Example |
|--------|-----------------|---------|
| `istio_requests_total` | Total request count | 1,234,567 requests to orders-svc |
| `istio_request_duration_milliseconds` | How long requests take | p99 latency is 250ms |
| `istio_request_bytes` | Request body size | Average 2.1 KB per request |
| `istio_response_bytes` | Response body size | Average 4.5 KB per response |

### TCP Metrics:

| Metric | What It Measures | Example |
|--------|-----------------|---------|
| `istio_tcp_connections_opened_total` | New connections | 500 new connections/minute |
| `istio_tcp_connections_closed_total` | Closed connections | 498 closed/minute |
| `istio_tcp_sent_bytes_total` | Data sent | 1.2 GB sent |
| `istio_tcp_received_bytes_total` | Data received | 800 MB received |

### Each metric has labels (dimensions):

```
istio_requests_total{
  source_workload="frontend",
  destination_workload="orders",
  response_code="200",
  request_protocol="http",
  connection_security_policy="mutual_tls"
} = 45231
```

---

## 🖥️ Grafana Dashboards

Istio comes with pre-built Grafana dashboards:

| Dashboard | What It Shows |
|-----------|--------------|
| **Mesh Dashboard** | Global overview of all services in the mesh |
| **Service Dashboard** | Deep dive into one specific service |
| **Workload Dashboard** | Pod-level metrics for a workload |
| **Performance Dashboard** | Envoy proxy resource usage |

### Access Grafana:

```bash
# Method 1: Istio built-in
istioctl dashboard grafana

# Method 2: Port forward
kubectl port-forward svc/grafana -n istio-system 3000:3000
# Open http://localhost:3000
```

---

## 📈 PromQL: Asking Questions

Prometheus uses **PromQL** to query metrics:

### "How many requests per second to the orders service?"
```promql
rate(istio_requests_total{destination_workload="orders"}[5m])
```

### "What's the error rate?"
```promql
sum(rate(istio_requests_total{response_code=~"5.*"}[5m]))
/
sum(rate(istio_requests_total[5m]))
* 100
```

### "What's the 99th percentile latency?"
```promql
histogram_quantile(0.99,
  rate(istio_request_duration_milliseconds_bucket{
    destination_workload="orders"
  }[5m])
)
```

---

## 🎓 Key Takeaways

1. **Zero code changes** — Envoy generates metrics for every request automatically
2. **Prometheus scrapes** metrics from every Envoy sidecar every 15 seconds
3. **Grafana visualizes** the data as dashboards and graphs
4. **Labels** let you filter by source, destination, status code, etc.
5. **PromQL** is the query language for asking questions about your metrics
6. **Pre-built dashboards** — Istio ships with Grafana dashboards ready to use
7. **The golden signals**: request rate, error rate, latency, saturation
