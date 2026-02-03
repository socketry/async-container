# Kubernetes Integration

This guide explains how to use `async-container` with Kubernetes to manage your application as a containerized service.

## Deployment Configuration

Create a deployment configuration file for your application:

```yaml
# my-app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: my-app-image:latest
          env:
            - name: NOTIFY_LOG
              value: "/tmp/notify.log"
          ports:
            - containerPort: 3000
          readinessProbe:
            exec:
              command: ["bundle", "exec", "bake", "async:container:notify:log:ready?"]
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 12
```

## Graceful Shutdown

Controllers handle `SIGTERM` gracefully (same as `SIGINT`). This ensures proper graceful shutdown when Kubernetes terminates pods during rolling updates, scaling down, or pod eviction.

**Note**: Kubernetes sends `SIGTERM` to containers when terminating pods. With graceful handling, your application will have time to clean up resources, finish in-flight requests, and shut down gracefully before Kubernetes sends `SIGKILL` (after the termination grace period).
