# Mastering Istio: Comprehensive YAML Examples

A complete guide to Istio service mesh configuration with practical YAML examples.

---

## Table of Contents

1. [Installation & Setup](#installation--setup)
2. [Gateway Configuration](#gateway-configuration)
3. [VirtualService](#virtualservice)
4. [DestinationRule](#destinationrule)
5. [ServiceEntry](#serviceentry)
6. [Traffic Management](#traffic-management)
7. [Security & Authentication](#security--authentication)
8. [Observability](#observability)
9. [Advanced Patterns](#advanced-patterns)

---

## Installation & Setup

### Basic Istio Installation

```yaml
# istio-operator.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: istio-control-plane
spec:
  profile: default
  components:
    pilot:
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 500m
            memory: 2048Mi
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          service:
            type: LoadBalancer
            ports:
              - port: 80
                targetPort: 8080
                name: http2
              - port: 443
                targetPort: 8443
                name: https
  meshConfig:
    accessLogFile: /dev/stdout
    enableTracing: true
    defaultConfig:
      tracing:
        zipkin:
          address: zipkin.istio-system:9411
```

### Namespace with Sidecar Injection

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio-injection: enabled
```

---

## Gateway Configuration

### HTTP Gateway

```yaml
# http-gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "example.com"
        - "*.example.com"
```

### HTTPS Gateway with TLS

```yaml
# https-gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: secure-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: example-com-cert
      hosts:
        - "secure.example.com"
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "secure.example.com"
      tls:
        httpsRedirect: true
```

### Multi-Protocol Gateway

```yaml
# multi-protocol-gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: multi-protocol-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "*.example.com"
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: wildcard-cert
      hosts:
        - "*.example.com"
    - port:
        number: 9080
        name: tcp
        protocol: TCP
      hosts:
        - "*"
```

---

## VirtualService

### Basic Routing

```yaml
# basic-virtualservice.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews-route
  namespace: default
spec:
  hosts:
    - reviews.default.svc.cluster.local
  http:
    - route:
        - destination:
            host: reviews.default.svc.cluster.local
            subset: v1
          weight: 100
```

### Traffic Splitting (Canary Deployment)

```yaml
# canary-virtualservice.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews-canary
spec:
  hosts:
    - reviews
  http:
    - match:
        - headers:
            end-user:
              exact: jason
      route:
        - destination:
            host: reviews
            subset: v2
    - route:
        - destination:
            host: reviews
            subset: v1
          weight: 90
        - destination:
            host: reviews
            subset: v2
          weight: 10
```

### URL Rewriting and Redirects

```yaml
# rewrite-redirect-virtualservice.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: api-routes
spec:
  hosts:
    - api.example.com
  gateways:
    - my-gateway
  http:
    - match:
        - uri:
            prefix: /old-api
      redirect:
        uri: /api/v2
        authority: api.example.com
    - match:
        - uri:
            prefix: /v1/users
      rewrite:
        uri: /api/users
      route:
        - destination:
            host: users-service
            port:
              number: 8080
```

### Advanced Matching

```yaml
# advanced-matching-virtualservice.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: advanced-routing
spec:
  hosts:
    - example.com
  gateways:
    - my-gateway
  http:
    - match:
        - headers:
            user-agent:
              regex: ".*Mobile.*"
          uri:
            prefix: /app
      route:
        - destination:
            host: mobile-service
    - match:
        - queryParams:
            version:
              exact: beta
      route:
        - destination:
            host: app-service
            subset: beta
    - match:
        - method:
            exact: POST
          uri:
            prefix: /api/v1/
      route:
        - destination:
            host: api-service
            subset: v1
    - route:
        - destination:
            host: app-service
            subset: stable
```

### Timeout and Retry Configuration

```yaml
# timeout-retry-virtualservice.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: timeout-retry-config
spec:
  hosts:
    - payment-service
  http:
    - route:
        - destination:
            host: payment-service
      timeout: 10s
      retries:
        attempts: 3
        perTryTimeout: 3s
        retryOn: 5xx,reset,connect-failure,refused-stream
```

### Fault Injection

```yaml
# fault-injection-virtualservice.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: fault-injection
spec:
  hosts:
    - ratings
  http:
    - match:
        - headers:
            end-user:
              exact: test
      fault:
        delay:
          percentage:
            value: 50.0
          fixedDelay: 5s
        abort:
          percentage:
            value: 10.0
          httpStatus: 503
      route:
        - destination:
            host: ratings
            subset: v1
    - route:
        - destination:
            host: ratings
            subset: v1
```

### CORS Configuration

```yaml
# cors-virtualservice.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: api-cors
spec:
  hosts:
    - api.example.com
  gateways:
    - my-gateway
  http:
    - corsPolicy:
        allowOrigins:
          - exact: https://app.example.com
          - prefix: https://*.example.com
        allowMethods:
          - POST
          - GET
          - PUT
          - DELETE
          - OPTIONS
        allowHeaders:
          - Content-Type
          - Authorization
          - X-Requested-With
        exposeHeaders:
          - X-Custom-Header
        maxAge: 24h
        allowCredentials: true
      route:
        - destination:
            host: api-service
```

---

## DestinationRule

### Basic Load Balancing

```yaml
# basic-destinationrule.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: reviews-destination
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
    - name: v3
      labels:
        version: v3
```

### Advanced Load Balancing

```yaml
# advanced-loadbalancing-destinationrule.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: advanced-lb
spec:
  host: my-service
  trafficPolicy:
    loadBalancer:
      consistentHash:
        httpHeaderName: x-user-id
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 40
```

### Circuit Breaking

```yaml
# circuit-breaker-destinationrule.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: circuit-breaker
spec:
  host: payment-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 10
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutiveGatewayErrors: 5
      consecutive5xxErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 100
```

### TLS Configuration

```yaml
# tls-destinationrule.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: tls-destination
spec:
  host: external-service.example.com
  trafficPolicy:
    tls:
      mode: MUTUAL
      clientCertificate: /etc/certs/client-cert.pem
      privateKey: /etc/certs/client-key.pem
      caCertificates: /etc/certs/ca-cert.pem
      sni: external-service.example.com
```

### Subset-Specific Policies

```yaml
# subset-policies-destinationrule.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: subset-policies
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: LEAST_REQUEST
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
      trafficPolicy:
        loadBalancer:
          simple: ROUND_ROBIN
    - name: v3
      labels:
        version: v3
      trafficPolicy:
        connectionPool:
          http:
            maxRequestsPerConnection: 1
```

---

## ServiceEntry

### External HTTP Service

```yaml
# external-http-serviceentry.yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-api
spec:
  hosts:
    - api.external.com
  ports:
    - number: 443
      name: https
      protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

### External Database

```yaml
# external-database-serviceentry.yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-database
spec:
  hosts:
    - postgres.external.com
  addresses:
    - 192.168.1.100/32
  ports:
    - number: 5432
      name: tcp
      protocol: TCP
  location: MESH_EXTERNAL
  resolution: STATIC
  endpoints:
    - address: 192.168.1.100
      ports:
        tcp: 5432
```

### Internal Service Discovery

```yaml
# internal-service-serviceentry.yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: internal-vm-service
spec:
  hosts:
    - vm-service.internal
  ports:
    - number: 8080
      name: http
      protocol: HTTP
  location: MESH_INTERNAL
  resolution: STATIC
  endpoints:
    - address: 10.0.0.10
      ports:
        http: 8080
      labels:
        version: v1
    - address: 10.0.0.11
      ports:
        http: 8080
      labels:
        version: v2
```

### Wildcard External Services

```yaml
# wildcard-serviceentry.yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: wildcard-external
spec:
  hosts:
    - "*.googleapis.com"
  ports:
    - number: 443
      name: https
      protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

---

## Traffic Management

### A/B Testing

```yaml
# ab-testing.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ab-testing
spec:
  hosts:
    - web-frontend
  http:
    - match:
        - headers:
            cookie:
              regex: "^(.*?;)?(experiment=variant-b)(;.*)?$"
      route:
        - destination:
            host: web-frontend
            subset: variant-b
    - route:
        - destination:
            host: web-frontend
            subset: variant-a
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ab-testing-destination
spec:
  host: web-frontend
  subsets:
    - name: variant-a
      labels:
        variant: a
    - name: variant-b
      labels:
        variant: b
```

### Blue-Green Deployment

```yaml
# blue-green-deployment.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: blue-green
spec:
  hosts:
    - app-service
  http:
    - route:
        - destination:
            host: app-service
            subset: green
          weight: 100
        - destination:
            host: app-service
            subset: blue
          weight: 0
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: blue-green-destination
spec:
  host: app-service
  subsets:
    - name: blue
      labels:
        version: blue
    - name: green
      labels:
        version: green
```

### Traffic Mirroring

```yaml
# traffic-mirroring.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: traffic-mirror
spec:
  hosts:
    - api-service
  http:
    - route:
        - destination:
            host: api-service
            subset: v1
          weight: 100
      mirror:
        host: api-service
        subset: v2
      mirrorPercentage:
        value: 100.0
```

### Header-Based Routing

```yaml
# header-routing.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: header-routing
spec:
  hosts:
    - reviews
  http:
    - match:
        - headers:
            x-api-version:
              exact: "v2"
      route:
        - destination:
            host: reviews
            subset: v2
    - match:
        - headers:
            x-api-version:
              prefix: "v1"
      route:
        - destination:
            host: reviews
            subset: v1
    - route:
        - destination:
            host: reviews
            subset: v1
```

---

## Security & Authentication

### Mutual TLS (mTLS) - Strict Mode

```yaml
# mtls-strict.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

### Namespace-Level mTLS

```yaml
# namespace-mtls.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: namespace-policy
  namespace: production
spec:
  mtls:
    mode: STRICT
```

### Workload-Level mTLS

```yaml
# workload-mtls.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: reviews-mtls
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  mtls:
    mode: STRICT
  portLevelMtls:
    9080:
      mode: DISABLE
```

### JWT Authentication

```yaml
# jwt-authentication.yaml
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: default
spec:
  selector:
    matchLabels:
      app: api-service
  jwtRules:
    - issuer: "https://auth.example.com"
      jwksUri: "https://auth.example.com/.well-known/jwks.json"
      audiences:
        - "api.example.com"
      forwardOriginalToken: true
```

### Authorization Policy - Allow

```yaml
# authz-policy-allow.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-specific-users
  namespace: default
spec:
  selector:
    matchLabels:
      app: api-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/default/sa/frontend"
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/api/v1/*"]
      when:
        - key: request.headers[x-user-role]
          values: ["admin", "developer"]
```

### Authorization Policy - Deny

```yaml
# authz-policy-deny.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-external-access
  namespace: production
spec:
  selector:
    matchLabels:
      app: database-service
  action: DENY
  rules:
    - from:
        - source:
            notNamespaces: ["production"]
```

### Authorization Policy - Custom Conditions

```yaml
# authz-policy-custom.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: custom-authz
  namespace: default
spec:
  selector:
    matchLabels:
      app: payment-service
  action: ALLOW
  rules:
    - from:
        - source:
            requestPrincipals: ["*"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/api/payment/*"]
      when:
        - key: request.auth.claims[iss]
          values: ["https://auth.example.com"]
        - key: request.auth.claims[scope]
          values: ["payment:write"]
```

### Combined Auth Configuration

```yaml
# combined-auth.yaml
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: combined-jwt
  namespace: default
spec:
  selector:
    matchLabels:
      app: secure-api
  jwtRules:
    - issuer: "https://auth.example.com"
      jwksUri: "https://auth.example.com/.well-known/jwks.json"
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: default
spec:
  selector:
    matchLabels:
      app: secure-api
  action: ALLOW
  rules:
    - from:
        - source:
            requestPrincipals: ["*"]
```

---

## Observability

### Telemetry Configuration

```yaml
# telemetry.yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  accessLogging:
    - providers:
        - name: envoy
  tracing:
    - providers:
        - name: jaeger
      randomSamplingPercentage: 100.0
      customTags:
        my_tag:
          literal:
            value: "my-value"
```

### Custom Metrics

```yaml
# custom-metrics.yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: custom-metrics
  namespace: default
spec:
  metrics:
    - providers:
        - name: prometheus
      overrides:
        - match:
            metric: REQUEST_COUNT
          tagOverrides:
            custom_dimension:
              value: "request.headers['x-custom-header']"
```

### Distributed Tracing

```yaml
# tracing-config.yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: tracing-config
  namespace: production
spec:
  tracing:
    - providers:
        - name: zipkin
      randomSamplingPercentage: 10.0
      customTags:
        environment:
          literal:
            value: "production"
        service_version:
          environment:
            name: SERVICE_VERSION
```

### Access Logging

```yaml
# access-logging.yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: access-log
  namespace: default
spec:
  accessLogging:
    - providers:
        - name: envoy
      filter:
        expression: response.code >= 400
      disabled: false
```

---

## Advanced Patterns

### Sidecar Resource Optimization

```yaml
# sidecar-optimization.yaml
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: production
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
```

### Workload-Specific Sidecar

```yaml
# workload-sidecar.yaml
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: reviews-sidecar
  namespace: default
spec:
  workloadSelector:
    labels:
      app: reviews
  ingress:
    - port:
        number: 9080
        protocol: HTTP
        name: http
      defaultEndpoint: 127.0.0.1:9080
  egress:
    - hosts:
        - "./ratings.default.svc.cluster.local"
        - "istio-system/*"
```

### Multi-Cluster Configuration

```yaml
# multi-cluster-gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: cross-cluster-gateway
  namespace: istio-system
spec:
  selector:
    istio: eastwestgateway
  servers:
    - port:
        number: 15443
        name: tls
        protocol: TLS
      tls:
        mode: AUTO_PASSTHROUGH
      hosts:
        - "*.local"
```

### EnvoyFilter for Advanced Customization

```yaml
# envoyfilter-ratelimit.yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: rate-limit-filter
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      app: api-gateway
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: "envoy.filters.network.http_connection_manager"
              subFilter:
                name: "envoy.filters.http.router"
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.local_ratelimit
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
            stat_prefix: http_local_rate_limiter
            token_bucket:
              max_tokens: 100
              tokens_per_fill: 10
              fill_interval: 1s
```

### Weighted Routing with Session Affinity

```yaml
# session-affinity.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: session-affinity
spec:
  hosts:
    - app-service
  http:
    - match:
        - headers:
            cookie:
              regex: "^(.*?;)?(session=.*)(;.*)?$"
      route:
        - destination:
            host: app-service
            subset: v2
    - route:
        - destination:
            host: app-service
            subset: v1
          weight: 80
        - destination:
            host: app-service
            subset: v2
          weight: 20
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: session-affinity-dr
spec:
  host: app-service
  trafficPolicy:
    loadBalancer:
      consistentHash:
        httpCookie:
          name: session
          ttl: 3600s
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

### Locality Load Balancing

```yaml
# locality-lb.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: locality-lb
spec:
  host: my-service.default.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      localityLbSetting:
        enabled: true
        distribute:
          - from: us-west/zone-1/*
            to:
              "us-west/zone-1/*": 80
              "us-west/zone-2/*": 20
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

### Egress Gateway for External Traffic

```yaml
# egress-gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: egress-gateway
  namespace: istio-system
spec:
  selector:
    istio: egressgateway
  servers:
    - port:
        number: 443
        name: tls
        protocol: TLS
      hosts:
        - external-api.example.com
      tls:
        mode: PASSTHROUGH
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: direct-through-egress
  namespace: default
spec:
  hosts:
    - external-api.example.com
  gateways:
    - mesh
    - istio-system/egress-gateway
  tls:
    - match:
        - gateways:
            - mesh
          port: 443
          sniHosts:
            - external-api.example.com
      route:
        - destination:
            host: istio-egressgateway.istio-system.svc.cluster.local
            port:
              number: 443
    - match:
        - gateways:
            - istio-system/egress-gateway
          port: 443
          sniHosts:
            - external-api.example.com
      route:
        - destination:
            host: external-api.example.com
            port:
              number: 443
          weight: 100
---
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-api
spec:
  hosts:
    - external-api.example.com
  ports:
    - number: 443
      name: tls
      protocol: TLS
  location: MESH_EXTERNAL
  resolution: DNS
```

---

## Best Practices Summary

### 1. **Start Simple**
- Begin with basic Gateway and VirtualService configurations
- Add complexity incrementally as needed

### 2. **Use Subsets Wisely**
- Define subsets in DestinationRule for version-based routing
- Keep subset names consistent across your deployment

### 3. **Enable mTLS**
- Start with PERMISSIVE mode, migrate to STRICT
- Apply at namespace level for easier management

### 4. **Monitor and Observe**
- Enable access logging and distributed tracing
- Use Kiali, Jaeger, and Prometheus for observability

### 5. **Circuit Breaking**
- Implement circuit breakers for external services
- Set appropriate thresholds based on service capacity

### 6. **Resource Optimization**
- Use Sidecar resources to limit configuration scope
- Set appropriate resource limits for proxies

### 7. **Security First**
- Always use AuthorizationPolicy for access control
- Implement JWT authentication for APIs
- Use egress gateways for external traffic control

### 8. **Testing**
- Test fault injection in non-production environments
- Validate traffic routing before production deployment
- Use traffic mirroring to test new versions safely

---

## Common Commands

```bash
# Install Istio
istioctl install --set profile=demo -y

# Enable sidecar injection
kubectl label namespace default istio-injection=enabled

# Verify installation
istioctl verify-install

# Analyze configuration
istioctl analyze

# Check proxy status
istioctl proxy-status

# View proxy configuration
istioctl proxy-config cluster <pod-name> -n <namespace>

# Dashboard
istioctl dashboard kiali
istioctl dashboard jaeger
istioctl dashboard grafana

# Uninstall Istio
istioctl uninstall --purge -y
kubectl delete namespace istio-system
```

---

## Troubleshooting Tips

1. **Traffic not routing correctly**
   - Check VirtualService and DestinationRule are in same namespace
   - Verify subset labels match pod labels
   - Use `istioctl analyze` to check configuration

2. **mTLS issues**
   - Check PeerAuthentication policy mode
   - Verify DestinationRule TLS settings
   - Check if services have sidecars injected

3. **Gateway not working**
   - Verify Gateway selector matches ingress gateway labels
   - Check VirtualService references correct Gateway
   - Ensure DNS is correctly configured

4. **High latency**
   - Check circuit breaker settings
   - Review connection pool configuration
   - Monitor for outlier detection ejections

---

This guide provides comprehensive YAML examples for mastering Istio. Start with basic configurations and progressively implement advanced patterns based on your requirements.
