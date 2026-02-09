# Project 1: Bookinfo - Traffic Management Basics

Learn Istio fundamentals through a complete microservices application deployment.

## Architecture

```
┌─────────────┐
│ productpage │ ← Frontend (Python)
└──────┬──────┘
       │
       ├──────> details    (Ruby)
       │
       └──────> reviews    (Java - 3 versions)
                   │
                   └──────> ratings (Node.js)
```

## Step 1: Deploy the Application

Save as `bookinfo-app.yaml`:

```yaml
# Details Service
apiVersion: v1
kind: Service
metadata:
  name: details
  namespace: demo
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: details
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: details-v1
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: details
      version: v1
  template:
    metadata:
      labels:
        app: details
        version: v1
    spec:
      containers:
      - name: details
        image: docker.io/istio/examples-bookinfo-details-v1:1.17.0
        ports:
        - containerPort: 9080
---
# Ratings Service
apiVersion: v1
kind: Service
metadata:
  name: ratings
  namespace: demo
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: ratings
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ratings-v1
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ratings
      version: v1
  template:
    metadata:
      labels:
        app: ratings
        version: v1
    spec:
      containers:
      - name: ratings
        image: docker.io/istio/examples-bookinfo-ratings-v1:1.17.0
        ports:
        - containerPort: 9080
---
# Reviews Service (3 versions)
apiVersion: v1
kind: Service
metadata:
  name: reviews
  namespace: demo
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: reviews
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v1
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v1
  template:
    metadata:
      labels:
        app: reviews
        version: v1
    spec:
      containers:
      - name: reviews
        image: docker.io/istio/examples-bookinfo-reviews-v1:1.17.0
        ports:
        - containerPort: 9080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v2
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v2
  template:
    metadata:
      labels:
        app: reviews
        version: v2
    spec:
      containers:
      - name: reviews
        image: docker.io/istio/examples-bookinfo-reviews-v2:1.17.0
        ports:
        - containerPort: 9080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v3
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v3
  template:
    metadata:
      labels:
        app: reviews
        version: v3
    spec:
      containers:
      - name: reviews
        image: docker.io/istio/examples-bookinfo-reviews-v3:1.17.0
        ports:
        - containerPort: 9080
---
# Productpage Service
apiVersion: v1
kind: Service
metadata:
  name: productpage
  namespace: demo
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: productpage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productpage-v1
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productpage
      version: v1
  template:
    metadata:
      labels:
        app: productpage
        version: v1
    spec:
      containers:
      - name: productpage
        image: docker.io/istio/examples-bookinfo-productpage-v1:1.17.0
        ports:
        - containerPort: 9080
```

## Step 2: Expose via Istio Gateway

Save as `bookinfo-gateway.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo-gateway
  namespace: demo
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo
  namespace: demo
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-gateway
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: productpage
        port:
          number: 9080
```

## Step 3: Define Traffic Subsets

Save as `bookinfo-destination-rules.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: productpage
  namespace: demo
spec:
  host: productpage
  subsets:
  - name: v1
    labels:
      version: v1
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
  namespace: demo
spec:
  host: reviews
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
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: ratings
  namespace: demo
spec:
  host: ratings
  subsets:
  - name: v1
    labels:
      version: v1
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: details
  namespace: demo
spec:
  host: details
  subsets:
  - name: v1
    labels:
      version: v1
```

## Deployment Commands

```bash
# Create namespace
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled

# Deploy application
kubectl apply -f bookinfo-app.yaml
kubectl apply -f bookinfo-gateway.yaml
kubectl apply -f bookinfo-destination-rules.yaml

# Verify pods are running
kubectl get pods -n demo
kubectl wait --for=condition=ready pod -l app=productpage -n demo

# Get ingress URL
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

# Test the application
curl -s http://${GATEWAY_URL}/productpage | grep -o "<title>.*</title>"
# Should see: <title>Simple Bookstore App</title>

# Open in browser
echo "http://${GATEWAY_URL}/productpage"
```

## Traffic Management Experiments

### Experiment 1: Route to v1 Only

Save as `reviews-v1.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: demo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
```

```bash
kubectl apply -f reviews-v1.yaml
# Refresh browser - NO stars visible
```

### Experiment 2: User-Based Routing

Save as `reviews-user-based.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: demo
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
```

```bash
kubectl apply -f reviews-user-based.yaml
# Login as "jason" - see BLACK stars
# Login as anyone else - see NO stars
```

### Experiment 3: Traffic Split (Canary)

Save as `reviews-canary.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: demo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 75
    - destination:
        host: reviews
        subset: v3
      weight: 25
```

```bash
kubectl apply -f reviews-canary.yaml
# 75% see NO stars, 25% see RED stars
```

### Experiment 4: Fault Injection - Delay

Save as `ratings-delay.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings
  namespace: demo
spec:
  hosts:
  - ratings
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    fault:
      delay:
        percentage:
          value: 100.0
        fixedDelay: 7s
    route:
    - destination:
        host: ratings
        subset: v1
  - route:
    - destination:
        host: ratings
        subset: v1
```

```bash
kubectl apply -f ratings-delay.yaml
# Login as "jason" - page loads slowly (7s delay)
```

### Experiment 5: Fault Injection - Abort

Save as `ratings-abort.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings
  namespace: demo
spec:
  hosts:
  - ratings
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    fault:
      abort:
        percentage:
          value: 100.0
        httpStatus: 500
    route:
    - destination:
        host: ratings
        subset: v1
  - route:
    - destination:
        host: ratings
        subset: v1
```

```bash
kubectl apply -f ratings-abort.yaml
# Login as "jason" - error message appears
```

### Experiment 6: Request Timeout

Save as `reviews-timeout.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: demo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v2
    timeout: 0.5s
```

```bash
# First inject delay in ratings
kubectl apply -f ratings-delay.yaml
# Then set timeout
kubectl apply -f reviews-timeout.yaml
# Login as "jason" - timeout error after 0.5s
```

### Experiment 7: Retry Logic

Save as `reviews-retry.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: demo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v2
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx,reset,connect-failure
```

## Monitoring with Kiali

```bash
# Open Kiali dashboard
istioctl dashboard kiali

# In Kiali:
# 1. Go to Graph
# 2. Select "demo" namespace
# 3. Display: "Versioned app graph"
# 4. Show: "Traffic Animation"
# 5. Generate traffic and watch flow
```

## Observability Commands

```bash
# View service mesh
kubectl get svc -n demo

# Check VirtualServices
kubectl get virtualservice -n demo
kubectl describe virtualservice reviews -n demo

# Check DestinationRules
kubectl get destinationrule -n demo

# View proxy configuration
istioctl proxy-config routes deploy/productpage-v1.demo

# Check proxy status
istioctl proxy-status

# Analyze configuration
istioctl analyze -n demo

# View access logs
kubectl logs -n demo deploy/productpage-v1 -c istio-proxy --tail=10
```

## Generate Load for Testing

```bash
# Simple load test
for i in {1..100}; do
  curl -s -o /dev/null http://${GATEWAY_URL}/productpage
done

# With different users
for i in {1..50}; do
  curl -s -o /dev/null -H "end-user: jason" http://${GATEWAY_URL}/productpage &
  curl -s -o /dev/null -H "end-user: mary" http://${GATEWAY_URL}/productpage &
done

# Install fortio for advanced load testing
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/httpbin/sample-client/fortio-deploy.yaml

# Run load test
FORTIO_POD=$(kubectl get pods -n demo -l app=fortio -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$FORTIO_POD" -n demo -c fortio -- /usr/bin/fortio load -c 3 -qps 0 -t 30s -loglevel Warning http://productpage:9080/productpage
```

## Cleanup

```bash
# Remove traffic rules
kubectl delete virtualservice reviews -n demo
kubectl delete virtualservice ratings -n demo

# Keep app running for next projects, or remove everything:
kubectl delete -f bookinfo-app.yaml
kubectl delete -f bookinfo-gateway.yaml
kubectl delete -f bookinfo-destination-rules.yaml
kubectl delete namespace demo
```

## Key Learnings

✅ **Traffic Routing**: Route requests based on headers, weights, or other criteria  
✅ **Fault Injection**: Test resilience by injecting delays and errors  
✅ **Timeouts & Retries**: Configure failure handling policies  
✅ **Canary Deployments**: Gradually shift traffic between versions  
✅ **Observability**: Monitor traffic flow with Kiali and logs  

**Next**: Move to Project 2 for advanced routing patterns!
