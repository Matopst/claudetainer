# Claudetainer

Claude CLI in Kubernetes for cluster troubleshooting.

A pod you deploy into your cluster, exec into, and use Claude to inspect resources, read logs, and diagnose issues, with whatever access its ServiceAccount has.

## Quick start

```bash
# Deploy
kubectl apply -f k8s/manifests.yaml

# Exec in and start Claude
kubectl exec -it deploy/claudetainer -- claude

# Authenticate (first time)
/login
```

## Deployment YAML

Copy-paste the block below to deploy without cloning the repo. Set `serviceAccountName` to your existing read-only ServiceAccount (default: `claudetainer`).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: claudetainer
  namespace: default
  labels:
    app: claudetainer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: claudetainer
  template:
    metadata:
      labels:
        app: claudetainer
    spec:
      serviceAccountName: claudetainer
      containers:
        - name: claude
          image: ghcr.io/matopst/claudetainer:latest
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "2"
          env:
            - name: GH_TOKEN
              valueFrom:
                secretKeyRef:
                  name: github-token
                  key: token
                  optional: true
          stdin: true
          tty: true
```

## Developer platform agent

On start the pod clones `intility/developer-platform-agent` into `~/developer-platform-agent` and runs `just setup` and `just pull`. This needs a GitHub token with read access to the intility repos, provided as a secret (the pod still starts without it, it just skips this step):

```bash
kubectl create secret generic github-token --from-literal=token=<token>
```

Restart the pod to re-sync, or run `just pull` in the repo.

## What's included

- Claude CLI
- kubectl
- curl
- jq
- dig
- ping
- vim
- net-tools
- openssl, netcat, traceroute, ps
- k9s (TUI cluster viewer)
- stern (multi-pod log tailing)
- helm (release inspection)
- gh and just

## RBAC

No RBAC is created. Attach the pod to an existing ServiceAccount (read-only access) via `serviceAccountName` in the Deployment.

## Clean up

```bash
kubectl delete deployment claudetainer
```

## Building from source

```bash
docker build -t claudetainer .
```
