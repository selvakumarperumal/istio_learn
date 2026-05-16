# Mutual TLS (mTLS) — Concept Explained

## 🤝 Real-World Analogy: Two-Way ID Check

**Regular TLS** (HTTPS) = You visit a bank website:
- Bank shows you its certificate → "I am really BankOfAmerica.com" ✅
- You don't prove who YOU are → Bank trusts anyone who visits

**Mutual TLS** (mTLS) = You visit a bank in person:
- Bank shows you their ID → "We are Bank of America" ✅
- You show your ID → "I am John Smith, account #1234" ✅
- **Both sides verify each other** before any transaction

In Istio: every service proves its identity to every other service. No exceptions.

---

## 🎯 The Problem Without mTLS

Inside a Kubernetes cluster, pods communicate over plain HTTP:

```
Pod A → HTTP (plain text) → Pod B

Anyone on the same network can:
  👀 READ your traffic (passwords, credit cards, API keys)
  ✏️ MODIFY your traffic (change amounts, inject malware)
  🎭 IMPERSONATE a service (fake Pod B intercepts requests)
```

**"But it's inside the cluster, so it's safe!"** — This is a **myth**.

Attackers who get into one pod can sniff ALL internal traffic. This is called a **lateral movement attack**.

---

## ✅ With mTLS: Encrypted + Authenticated

```
Pod A (client)                         Pod B (server)
┌──────────────┐                      ┌──────────────┐
│ Envoy Sidecar│ ─── mTLS tunnel ───▶ │ Envoy Sidecar│
│              │   🔒 Encrypted       │              │
│ Certificate: │   🪪 Verified        │ Certificate: │
│ "I am svc-A" │                      │ "I am svc-B" │
└──────────────┘                      └──────────────┘
```

Now an attacker:
- ❌ Can't READ traffic (encrypted with TLS 1.3)
- ❌ Can't MODIFY traffic (integrity protected)
- ❌ Can't IMPERSONATE (needs a valid certificate from Istio CA)

---

## 🔑 How Istio mTLS Works Automatically

### Step 1: Certificate Distribution

```
┌───────────────────────────────────┐
│ Istiod (Control Plane)            │
│ ┌───────────┐                     │
│ │ Istio CA   │ Certificate Authority│
│ │ (built-in) │                     │
│ └─────┬─────┘                     │
└───────┼───────────────────────────┘
        │ Issues certificates to every sidecar
        │
   ┌────┴────┐  ┌────┴────┐  ┌────┴────┐
   │ Envoy A │  │ Envoy B │  │ Envoy C │
   │ Cert:   │  │ Cert:   │  │ Cert:   │
   │ svc-A   │  │ svc-B   │  │ svc-C   │
   └─────────┘  └─────────┘  └─────────┘
```

- Istiod has a built-in **Certificate Authority (CA)**
- When a pod starts, its sidecar proxy gets a unique certificate
- Certificates are **automatically rotated** (default: every 24 hours)
- **No manual certificate management needed!**

### Step 2: mTLS Handshake (Every Connection)

```
Envoy A                                    Envoy B
   │                                          │
   │  1. "Hello, I want to connect"           │
   │─────────────────────────────────────────▶│
   │                                          │
   │  2. "Here's my certificate (svc-B)"      │
   │◀─────────────────────────────────────────│
   │                                          │
   │  3. Verify cert against Istio CA ✅      │
   │                                          │
   │  4. "Here's MY certificate (svc-A)"      │
   │─────────────────────────────────────────▶│
   │                                          │
   │  5. Verify cert against Istio CA ✅      │
   │                                          │
   │  6. 🔒 Encrypted channel established     │
   │◀════════════════════════════════════════▶│
   │  All data encrypted from now on          │
   │                                          │
```

---

## 🔐 Two Modes: STRICT vs PERMISSIVE

### STRICT Mode: "Papers, please!"

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
spec:
  mtls:
    mode: STRICT  # mTLS required — no exceptions!
```

```
Service A (with sidecar) → Service B: ✅ mTLS works
Legacy App (no sidecar)  → Service B: ❌ REJECTED (no cert!)
```

**Use when:** All services have Istio sidecars (full mesh)

### PERMISSIVE Mode: "Show ID if you have one"

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
spec:
  mtls:
    mode: PERMISSIVE  # Accept both mTLS and plain HTTP
```

```
Service A (with sidecar) → Service B: ✅ mTLS works
Legacy App (no sidecar)  → Service B: ✅ Plain HTTP allowed
```

**Use when:** Migrating to Istio (some services don't have sidecars yet)

---

## 🚀 Migration Strategy

```
Step 1: Start with PERMISSIVE (safe)
        → Old and new services can communicate
        → mTLS is used when possible, plain HTTP as fallback

Step 2: Add sidecars to ALL services
        → Monitor: Are all connections using mTLS?
        → Check: kubectl get peerauthentication --all-namespaces

Step 3: Switch to STRICT (secure)
        → Only mTLS connections accepted
        → Any non-mesh traffic is rejected

Step 4: Verify
        → Send plain HTTP request → should get REJECTED
        → All legitimate traffic flows normally
```

---

## 🔍 How to Verify mTLS is Working

### Check if connections are encrypted:

```bash
# From a pod WITH sidecar (should work in STRICT mode)
kubectl exec <pod-with-sidecar> -- curl http://httpbin:80/get
# ✅ Works — Envoy handles mTLS transparently

# From a pod WITHOUT sidecar (should fail in STRICT mode)
kubectl exec <pod-without-sidecar> -- curl http://httpbin:80/get
# ❌ Connection reset — no mTLS certificate!
```

### What happens behind the scenes:

```
Your app sends:     curl http://httpbin:80/get  (plain HTTP)
Envoy intercepts:   Upgrades to mTLS automatically
Actual connection:  TLS 1.3 encrypted tunnel to httpbin's Envoy
httpbin's Envoy:    Decrypts and forwards as plain HTTP to httpbin app

Your app thinks it's using HTTP → Actually using mTLS!
```

---

## 🆚 mTLS vs Regular TLS

| Feature | Regular TLS (HTTPS) | Mutual TLS (mTLS) |
|---------|--------------------|--------------------|
| Server proves identity | ✅ Yes | ✅ Yes |
| Client proves identity | ❌ No | ✅ Yes |
| Certificate management | Manual | Automatic (Istio CA) |
| Rotation | Manual (Let's Encrypt) | Auto (every 24h) |
| Scope | Edge (internet→cluster) | Everywhere (pod→pod) |

---

## 🎓 Key Takeaways

1. **mTLS = both sides verify** — server AND client show certificates
2. **Automatic** — Istio CA issues and rotates certs, zero manual work
3. **Transparent** — apps send plain HTTP, Envoy handles encryption
4. **STRICT mode** = enforce mTLS everywhere (production goal)
5. **PERMISSIVE mode** = allow mixed traffic (migration phase)
6. **Zero trust** — don't assume internal network is safe
7. **Identity-based** — services have cryptographic identities, not just IP addresses
