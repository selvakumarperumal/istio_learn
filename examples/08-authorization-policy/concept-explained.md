# Authorization Policy — Concept Explained

## 🏢 Real-World Analogy: Office Building Security

Imagine a corporate office building:

- **Front door** = Gateway (anyone can reach it)
- **Reception desk** = mTLS (prove you're an employee)
- **Key card system** = Authorization Policy (which ROOMS can you access?)

Even if you're a verified employee (mTLS ✅), you can't access:
- ❌ The server room (only IT team)
- ❌ The CEO's office (only executives)
- ❌ The finance vault (only finance team)

**mTLS = "Are you who you say you are?" (authentication)**
**AuthorizationPolicy = "Are you allowed to do THIS?" (authorization)**

---

## 🎯 The Problem

With just mTLS, any service can talk to any other service:

```
✅ frontend → orders (should be allowed)
✅ frontend → database (should NOT be allowed!)
✅ orders   → database (should be allowed)
✅ random-pod → database (should NOT be allowed!)
```

Without authorization policies, a compromised frontend pod can directly access your database!

---

## 🛡️ The Zero-Trust Approach

### Step 1: Deny ALL Traffic (Lock Everything)

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: my-namespace
spec: {}  # Empty spec = deny everything!
```

```
frontend → orders:   ❌ DENIED
frontend → database: ❌ DENIED
orders   → database: ❌ DENIED
EVERYTHING → ANYTHING: ❌ DENIED
```

**Now nothing works** — but nothing is vulnerable either! 🔒

### Step 2: Allow ONLY Specific Traffic

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-to-orders
  namespace: my-namespace
spec:
  selector:
    matchLabels:
      app: orders          # This policy applies TO the orders service
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/my-namespace/sa/frontend-sa"
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/api/orders/*"]
```

```
frontend → orders /api/orders/123:          ✅ ALLOWED
frontend → orders /admin/delete-all:        ❌ DENIED (wrong path)
database → orders /api/orders/123:          ❌ DENIED (wrong identity)
frontend → database:                        ❌ DENIED (no policy for database)
```

---

## 🔍 How Authorization Policies Work

### The Decision Flow

```
Request arrives at Pod B's Envoy sidecar
     │
     ▼
  Is there a deny-all policy?
     │
  ┌──┴──┐
  │ YES │ → Check allow policies
  └─────┘
     │
     ▼
  Does the request match ANY allow policy?
     │
  ┌──┴──────────┐
  │ YES (match) │ → ✅ ALLOW (request proceeds)
  └─────────────┘
  │ NO (no match) │
  └───────────────┘
     │
     ▼
  ❌ DENY (return 403 Forbidden)
```

### What gets checked:

| Field | What It Checks | Example |
|-------|---------------|---------|
| `source.principals` | WHO is making the request (ServiceAccount identity) | `frontend-sa` |
| `source.namespaces` | WHERE the request comes from | `production` |
| `operation.methods` | HTTP method | `GET`, `POST`, `DELETE` |
| `operation.paths` | URL path | `/api/orders/*` |
| `operation.ports` | Port number | `8080` |

---

## 🪪 Identity: How Does Istio Know WHO Is Calling?

Istio uses **ServiceAccount identities** from mTLS certificates:

```
Pod → runs as ServiceAccount "frontend-sa"
    → Envoy gets certificate: "cluster.local/ns/default/sa/frontend-sa"
    → This is the "principal" used in authorization policies
```

```
Every pod has a cryptographic identity:

  cluster.local/ns/<namespace>/sa/<service-account>

  Example: cluster.local/ns/production/sa/frontend-sa
           ────────────── ── ────────── ── ───────────
           trust domain   ns  namespace  sa  account name
```

---

## 📊 Three Policy Actions

### ALLOW (Whitelist)
```yaml
spec:
  action: ALLOW    # Or omit (ALLOW is default)
  rules:
    - from: [...]  # Match this source
      to: [...]    # Match this destination
```
"If the request matches → let it through"

### DENY (Blacklist)
```yaml
spec:
  action: DENY
  rules:
    - from: [...]
```
"If the request matches → block it (even if an ALLOW policy exists)"

### CUSTOM (External auth)
```yaml
spec:
  action: CUSTOM
  provider:
    name: my-oauth-server
```
"Ask an external service to decide"

### Evaluation order:
```
1. CUSTOM policies (if any) → checked first
2. DENY policies → if matched, request is DENIED (no matter what)
3. ALLOW policies → if matched, request is ALLOWED
4. No matching policy → DENIED (if deny-all exists)
```

> **DENY always wins over ALLOW!**

---

## 🧪 Practical Example

### Setup:
```
Namespace: authz-demo
  ├── frontend (ServiceAccount: frontend-sa)
  ├── orders   (ServiceAccount: orders-sa)
  └── database (ServiceAccount: database-sa)
```

### Policies:
```yaml
# Policy 1: Deny everything by default
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: authz-demo
spec: {}

---
# Policy 2: Frontend can call orders (GET only)
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-to-orders
  namespace: authz-demo
spec:
  selector:
    matchLabels:
      app: orders
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/authz-demo/sa/frontend-sa"]
      to:
        - operation:
            methods: ["GET"]

---
# Policy 3: Orders can call database
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-orders-to-database
  namespace: authz-demo
spec:
  selector:
    matchLabels:
      app: database
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/authz-demo/sa/orders-sa"]
```

### Result:
```
frontend → GET orders:     ✅ (Policy 2 allows)
frontend → POST orders:    ❌ (Policy 2 only allows GET)
frontend → database:       ❌ (No policy allows this)
orders → database:         ✅ (Policy 3 allows)
random-pod → anything:     ❌ (No policy allows this)
```

---

## 🎓 Key Takeaways

1. **Start with deny-all** — lock everything, then open specific paths
2. **Identity-based** — uses ServiceAccount names, not IP addresses
3. **DENY wins** — a DENY policy overrides any ALLOW policy
4. **Selector** = which pods the policy applies TO (destination)
5. **Source** = who is allowed to call (origin)
6. **Combine with mTLS** — authentication (who are you) + authorization (what can you do)
7. **Policy propagation takes ~1-2 seconds** — wait before testing after applying
