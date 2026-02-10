# JWT Authentication — Concept Explained

## 🎫 Real-World Analogy: Concert Wristband

At a music festival:

1. You show your **ticket** at the gate → staff checks it's valid
2. They give you a **wristband** (color-coded: VIP=gold, General=blue)
3. At each stage, security checks your **wristband color**
4. Gold wristband → backstage access ✅
5. Blue wristband → backstage access ❌

**JWT = the wristband.** It carries WHO you are and WHAT you're allowed to do.

---

## 🎯 What is a JWT?

JWT = **JSON Web Token** — a digitally signed string with three parts:

```
eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJ0ZXN0aW5nQHNlY3VyZS5pc3Rpby5pbyIsInN1YiI6InRlc3RpbmdAc2VjdXJlLmlzdGlvLmlvIn0.dL5GR...
└────── Header ───────┘ └──────────────────── Payload ──────────────────────────────────────────────────────────────────┘ └─ Signature ─┘
```

### Decoded:

```json
// Header: HOW the token was signed
{
  "alg": "RS256",     // Algorithm: RSA with SHA-256
  "typ": "JWT"        // Type: JSON Web Token
}

// Payload: WHO the user is + WHAT they can do (claims)
{
  "iss": "testing@secure.istio.io",   // Issuer: who created this token
  "sub": "testing@secure.istio.io",   // Subject: who this token is for
  "exp": 4685989700,                   // Expires: when it stops working
  "groups": ["group1", "group2"]       // Custom claim: user's groups
}

// Signature: PROOF that nothing was tampered with
// Created by: sign(header + payload, private_key)
// Verified by: verify(signature, public_key)
```

---

## ⚙️ How JWT + Istio Works

### Step-by-Step: Request with JWT

```
┌─────────┐    ┌───────────────────────────────────┐    ┌──────────┐
│ Client   │───▶│  Envoy Sidecar                    │───▶│  httpbin  │
│          │    │                                   │    │  pod      │
│ Headers: │    │  1. Extract JWT from header        │    └──────────┘
│ Auth:    │    │     Authorization: Bearer <token>  │
│ Bearer   │    │                                   │
│ <JWT>    │    │  2. Download JWKS (public keys)    │
│          │    │     from issuer's JWKS URL         │
│          │    │                                   │
│          │    │  3. Verify signature                │
│          │    │     valid? → continue              │
│          │    │     invalid? → 401 Unauthorized    │
│          │    │                                   │
│          │    │  4. Check expiration                │
│          │    │     expired? → 401 Unauthorized    │
│          │    │                                   │
│          │    │  5. Check AuthorizationPolicy       │
│          │    │     claims match? → ✅ ALLOW        │
│          │    │     no match? → ❌ 403 Forbidden    │
│          │    │                                   │
└─────────┘    └───────────────────────────────────┘
```

### Two Istio Resources Work Together:

```
RequestAuthentication           AuthorizationPolicy
(Verifies the JWT)             (Checks the claims)
        │                              │
        ▼                              ▼
"Is this token valid?"         "Is this user allowed?"
"Was it issued by our          "Do they have the right
 trusted issuer?"               groups/roles?"
```

---

## 🔑 JWKS: How Does Envoy Get the Public Key?

```
1. You configure a JWKS URL in RequestAuthentication:
   jwksUri: "https://raw.githubusercontent.com/.../jwks.json"

2. Envoy downloads the public keys from that URL:
   { "keys": [{ "kty": "RSA", "n": "...", "e": "AQAB" }] }

3. For each JWT, Envoy uses the public key to verify the signature

4. Keys are cached and refreshed periodically
```

> **Think of JWKS as a directory of public keys that Envoy uses to verify JWTs** — similar to how a bouncer has a list of valid wristband patterns.

---

## 📋 Three Scenarios

### Scenario 1: No JWT → What happens?

```bash
curl http://httpbin/get
# No Authorization header
```

**With only RequestAuthentication (no AuthorizationPolicy):**
→ ✅ Request passes! (RequestAuthentication only validates present tokens)

**With RequestAuthentication + AuthorizationPolicy requiring JWT:**
→ ❌ 403 Forbidden

### Scenario 2: Valid JWT → Allowed

```bash
curl -H "Authorization: Bearer <valid-token>" http://httpbin/get
```

```
Step 1: Extract JWT from header ✅
Step 2: Verify signature with JWKS public key ✅
Step 3: Check expiration → not expired ✅
Step 4: Check issuer matches → matches ✅
Step 5: AuthorizationPolicy checks claims → match ✅
Result: Request forwarded to httpbin
```

### Scenario 3: Invalid JWT → Rejected

```bash
curl -H "Authorization: Bearer <expired-token>" http://httpbin/get
```

```
Step 1: Extract JWT from header ✅
Step 2: Verify signature ✅
Step 3: Check expiration → EXPIRED! ❌
Result: 401 Unauthorized (stopped at Envoy, never reaches httpbin)
```

---

## 🔧 Configuration Breakdown

### RequestAuthentication: "Who do we trust?"

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
spec:
  selector:
    matchLabels:
      app: httpbin          # Apply to httpbin pods
  jwtRules:
    - issuer: "testing@secure.istio.io"   # Trust tokens from this issuer
      jwksUri: "https://...jwks.json"     # Get public keys from here
```

### AuthorizationPolicy: "What claims are required?"

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: httpbin
  rules:
    - from:
        - source:
            requestPrincipals: ["testing@secure.istio.io/testing@secure.istio.io"]
                              # format: <issuer>/<subject> from the JWT
```

---

## 🆚 JWT vs mTLS vs API Key

| Feature | JWT | mTLS | API Key |
|---------|-----|------|---------|
| **Who uses it** | End users, external clients | Services (pod-to-pod) | External apps |
| **Identity** | User identity (email, role) | Service identity (ServiceAccount) | App identity |
| **Carries claims** | ✅ (groups, roles, permissions) | ❌ (just identity) | ❌ (just a key) |
| **Expiration** | ✅ (exp claim) | ✅ (cert rotation) | ❌ (usually permanent) |
| **Managed by** | Auth provider (Auth0, Keycloak) | Istio CA (automatic) | Manual |

---

## 🎓 Key Takeaways

1. **JWT = signed token** with identity claims (who + what permissions)
2. **RequestAuthentication** = validates the token (signature, expiry, issuer)
3. **AuthorizationPolicy** = checks the claims (does user have the right role?)
4. **JWKS** = public key directory used to verify JWT signatures
5. **No JWT ≠ rejected** — RequestAuthentication alone allows requests without JWT
6. **Three-part token**: header (how signed) + payload (claims) + signature (proof)
7. **Zero code changes** — Envoy validates JWTs before they reach your app
