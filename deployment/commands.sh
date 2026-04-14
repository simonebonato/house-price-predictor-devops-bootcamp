#!/bin/bash
# =============================================================================
# House Price Predictor API - Useful Commands Reference
# =============================================================================
# Usage: copy-paste individual commands as needed, or run specific sections.
# API is exposed via NodePort at localhost:30100
# Deployment name: fastapi | Service name: fastapi
# =============================================================================


# -----------------------------------------------------------------------------
# PREDICTIONS
# -----------------------------------------------------------------------------

# Make a prediction using a JSON file
curl -X POST http://localhost:30100/predict \
  -H "Content-Type: application/json" \
  -d @predict.json

# Make a prediction with inline JSON
curl -X POST http://localhost:30100/predict \
  -H "Content-Type: application/json" \
  -d '{
    "sqft": 4500,
    "bedrooms": 4,
    "bathrooms": 2,
    "year_built": 2014,
    "condition": "Good",
    "location": "Urban"
  }'


# -----------------------------------------------------------------------------
# HEALTH & READINESS
# -----------------------------------------------------------------------------

# Check if the API is alive
curl http://localhost:30100/health

# Check readiness (used by Kubernetes readiness probe)
curl http://localhost:30100/ready

# Check the root endpoint
curl http://localhost:30100/


# -----------------------------------------------------------------------------
# PROMETHEUS METRICS
# -----------------------------------------------------------------------------

# Scrape raw Prometheus metrics from the API
curl http://localhost:30100/metrics

# Query Prometheus directly - p95 latency
curl "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))'

# Query Prometheus directly - total request rate
curl "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=sum(rate(http_requests_total[1m]))'

# Query Prometheus directly - error rate (5xx)
curl "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=sum(rate(http_requests_total{status_code=~"5.."}[1m]))'


# -----------------------------------------------------------------------------
# KUBERNETES - PODS & DEPLOYMENTS
# -----------------------------------------------------------------------------

# List all pods in the default namespace
kubectl get pods

# List all pods with more details (node, IP, age)
kubectl get pods -o wide

# Describe the model deployment
kubectl describe deployment fastapi

# Check deployment scaling status
kubectl get deployment fastapi

# Watch pods in real time
kubectl get pods -w

# Get logs from the model pod (replace <pod-name>)
kubectl logs <pod-name>

# Stream live logs from the model pod
kubectl logs -f <pod-name>

# Get logs from a previously crashed container
kubectl logs <pod-name> --previous


# -----------------------------------------------------------------------------
# KUBERNETES - SCALING
# -----------------------------------------------------------------------------

# Manually scale the deployment to 3 replicas
kubectl scale deployment fastapi --replicas=3

# Check current HPA / KEDA ScaledObject status
kubectl get scaledobject
kubectl describe scaledobject fastapi-latency-autoscaler


# -----------------------------------------------------------------------------
# KUBERNETES - SERVICES & NETWORKING
# -----------------------------------------------------------------------------

# List all services
kubectl get svc

# Describe the model service (check NodePort)
kubectl describe svc fastapi

# Port-forward the model service locally on port 8080
kubectl port-forward svc/fastapi 8080:8000


# -----------------------------------------------------------------------------
# ARGOCD
# -----------------------------------------------------------------------------

# Expose ArgoCD UI via NodePort on port 32100
# By default argocd-server is ClusterIP (not accessible outside cluster).
# This patches it to NodePort so you can reach the UI at https://localhost:32100
kubectl patch svc argocd-server -n argocd --patch \
  --type='json' \
  -p='[{"spec": {"type": "NodePort", "ports": [{"nodePort": 32100, "port": 443, "protocol": "TCP", "targetPort": 8080}]}}]'


# Access ArgoCD UI at https://localhost:32100 — username: admin

# Reset ArgoCD admin password (use when initial secret is missing or login fails)
# The argocd-initial-admin-secret is auto-deleted after first login.
# Steps:
#   1. Generate bcrypt hash of desired password (requires apache2-utils: brew install httpd)
#   2. Patch argocd-secret with the hash
#   3. Restart argocd-server to pick up the change
#   4. Login with: username=admin, password=RADU0uh7CaChLa
HASH=$(htpasswd -nbBC 10 "" RADU0uh7CaChLa | tr -d ':\n' | sed 's/$2y/$2a/')
kubectl -n argocd patch secret argocd-secret \
  -p "{\"stringData\": {
    \"admin.password\": \"$HASH\",
    \"admin.passwordMtime\": \"$(date +%FT%T%Z)\"
  }}"
kubectl rollout restart deployment argocd-server -n argocd


# -----------------------------------------------------------------------------
# LOAD TESTING (requires `hey` or `ab`)
# -----------------------------------------------------------------------------

# Send 500 requests with 10 concurrent workers using hey
hey -n 500 -c 10 -m POST \
  -H "Content-Type: application/json" \
  -d '{"sqft":4500,"bedrooms":4,"bathrooms":2,"year_built":2014,"condition":"Good","location":"Urban"}' \
  http://localhost:30100/predict

# Send 5000 requests with 200 concurrent workers (high load test)
hey -n 5000 -c 200 -m POST \
  -H "Content-Type: application/json" \
  -D /Users/simone.bonato/Desktop/MLOps_course/predict.json \
  http://localhost:30100/predict

# Run a sustained load test for 3 minutes with 200 concurrent workers
# Useful for triggering KEDA autoscaling and observing Grafana dashboards
hey -z 3m -c 400 -m POST \
  -H "Content-Type: application/json" \
  -D /Users/simone.bonato/Desktop/MLOps_course/predict.json \
  http://localhost:30100/predict

# Send 1000 requests with Apache Bench (ab)
ab -n 1000 -c 20 \
  -T "application/json" \
  -p /Users/simone.bonato/Desktop/MLOps_course/predict.json \
  http://localhost:30100/predict