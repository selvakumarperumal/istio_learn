# test.sh — Line-by-Line Explanation

## Overview

This script tests all three Istio fault injection modes (delay, abort, combined) by sending HTTP requests through the Istio Ingress Gateway and measuring response times and status codes.

---

## Section 1: Gateway URL Discovery

```bash
GATEWAY_URL=""
```
Initialize an empty variable to hold the gateway URL.

```bash
EXTERNAL_IP=$(kubectl get svc -n istio-ingress istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
```
**Try LoadBalancer IP first.** In cloud environments (GKE, EKS) or when `minikube tunnel` is running, the Istio Ingress Gateway gets an external IP via the `LoadBalancer` service type. This command queries the service's `.status.loadBalancer.ingress[0].ip` field.

- `-o jsonpath='{...}'` — Extract a specific JSON field from the Kubernetes API response
- `2>/dev/null` — Suppress stderr errors (e.g., if the field doesn't exist)

```bash
if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
    GATEWAY_URL="http://$EXTERNAL_IP"
```
If we got a non-empty, non-null external IP, use it as the gateway URL.

```bash
else
    NODE_PORT=$(kubectl get svc -n istio-ingress istio-ingressgateway \
      -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null)
```
**Fallback to NodePort.** If no LoadBalancer IP exists (typical for Minikube without tunnel), get the NodePort number. The `jsonpath` filter `?(@.name=="http2")` finds the port entry named `http2` (Istio's HTTP port) and extracts its `nodePort` value.

```bash
    MINIKUBE_IP=$(minikube ip 2>/dev/null)
```
Get the Minikube VM's IP address. This is the IP where NodePort services are accessible.

```bash
    if [ -n "$NODE_PORT" ] && [ -n "$MINIKUBE_IP" ]; then
        GATEWAY_URL="http://$MINIKUBE_IP:$NODE_PORT"
```
Construct the gateway URL as `http://<minikube-ip>:<nodeport>`.

For example: `http://192.168.49.2:32268`

---

## Section 2: VirtualService Cleanup Helper

```bash
cleanup_vs() {
    kubectl delete vs httpbin-delay httpbin-abort httpbin-combined \
      -n fault-demo --ignore-not-found 2>/dev/null
    sleep 2
}
```

### Why this exists

This is the **most critical function** in the script. Istio allows only **one VirtualService per host** to work predictably. If multiple VirtualServices target the same host (`httpbin`), Istio's behavior becomes undefined — you get random 503 errors and no faults applied.

| Part | Purpose |
|---|---|
| `kubectl delete vs` | Delete VirtualService resources (short name: `vs`) |
| `httpbin-delay httpbin-abort httpbin-combined` | All three possible fault VS names |
| `--ignore-not-found` | Don't error if a VS doesn't exist |
| `2>/dev/null` | Suppress any warning output |
| `sleep 2` | Wait for Envoy proxies to receive the updated config from Istiod (config propagation takes ~1-2s) |

---

## Section 3: Request Sender Helper

```bash
send_requests() {
    local COUNT=${1:-10}
```
Accept a count argument (default: 10). `local` scopes the variable to the function. `${1:-10}` means "use first argument, or 10 if not provided".

```bash
    for i in $(seq 1 $COUNT); do
```
Loop from 1 to COUNT. `seq 1 $COUNT` generates the sequence `1 2 3 ... COUNT`.

```bash
        START=$(date +%s%N)
```
Capture the start time in **nanoseconds** since epoch.

| Format | Meaning | Example |
|---|---|---|
| `%s` | Seconds since epoch | `1707500000` |
| `%N` | Nanoseconds (0-999999999) | `123456789` |
| `%s%N` | Combined: seconds + nanoseconds | `1707500000123456789` |

```bash
        CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Host: httpbin.example.com" \
            --max-time 10 \
            "$GATEWAY_URL/get" 2>/dev/null)
```

| Flag | Purpose |
|---|---|
| `-s` | Silent mode — no progress bar |
| `-o /dev/null` | Discard the response body (we only want the status code) |
| `-w "%{http_code}"` | Write ONLY the HTTP status code to stdout |
| `-H "Host: httpbin.example.com"` | Set the Host header — **required** because the Gateway is configured to route traffic for this hostname |
| `--max-time 10` | Timeout after 10 seconds (prevents hanging on broken routes) |
| `$GATEWAY_URL/get` | The httpbin `/get` endpoint |

```bash
        END=$(date +%s%N)
```
Capture the end time in nanoseconds.

```bash
        DURATION_MS=$(( (END - START) / 1000000 ))
```
Calculate duration in **milliseconds** using integer arithmetic:
- `END - START` = duration in nanoseconds
- `/ 1000000` = convert nanoseconds → milliseconds

```bash
        DURATION_S=$(echo "scale=1; $DURATION_MS / 1000" | bc)
```
Convert milliseconds to seconds with 1 decimal place using `bc` (the calculator tool):
- `scale=1` — one decimal place
- Example: `5023 / 1000` → `5.0`

```bash
        if [ "$CODE" == "503" ]; then
            echo "  Request $i: HTTP $CODE  ${DURATION_S}s  ← ABORTED"
```
If HTTP 503, label it as **ABORTED** — the Envoy proxy returned the error without contacting the backend.

```bash
        elif (( DURATION_MS > 2000 )); then
            echo "  Request $i: HTTP $CODE  ${DURATION_S}s  ← DELAYED"
```
If the request took more than 2 seconds, label it as **DELAYED** — the Envoy proxy held the request before forwarding it.

```bash
        else
            echo "  Request $i: HTTP $CODE  ${DURATION_S}s"
```
Otherwise, the request passed through normally — no fault injected.

---

## How Fault Injection Works at the Envoy Level

```
┌──────────┐    ┌──────────────────────────────────┐    ┌──────────┐
│  Client   │───▶│  Envoy Sidecar (istio-proxy)     │───▶│  httpbin  │
│ (curl)    │    │                                  │    │  pod      │
└──────────┘    │  For EACH request:                │    └──────────┘
                │                                    │
                │  1. Check ABORT rules              │
                │     Roll dice → 50% chance?        │
                │     YES → Return HTTP 503          │
                │           (httpbin never called!)   │
                │     NO  → Continue                 │
                │                                    │
                │  2. Check DELAY rules              │
                │     Roll dice → 50% chance?        │
                │     YES → Sleep 5s, then forward   │
                │     NO  → Forward immediately      │
                │                                    │
                └──────────────────────────────────┘
```

> **Key insight**: Abort is checked FIRST. If a request is aborted, it never reaches the delay check or the backend pod.
