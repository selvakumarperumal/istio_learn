# Mastering Istio: Complete Application Deployment Guide

A comprehensive, hands-on guide with complete application deployments demonstrating all Istio concepts from basics to production.

---

## Quick Start

```bash
# Clone examples repository
git clone https://github.com/istio/istio
cd istio

# Install Istio
istioctl install --set profile=demo -y

# Enable sidecar injection
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled

# Install observability tools
kubectl apply -f samples/addons
```

---

## Table of Contents

**Part 1: Foundations** 
- [Project 1: Bookinfo - Traffic Management Basics](#project-1-bookinfo)
- [Project 2: E-Commerce Platform - Advanced Routing](#project-2-ecommerce)

**Part 2: Security & Production**
- [Project 3: API Gateway with Security](#project-3-api-gateway)
- [Project 4: Progressive Canary Deployment](#project-4-canary)

**Part 3: Operations**
- [Project 5: Complete Observability Stack](#project-5-observability)
- [Project 6: Production-Ready Deployment](#project-6-production)

[View detailed examples in separate files]

---

