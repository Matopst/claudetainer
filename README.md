# Claudetainer

Claude CLI in Kubernetes for cluster troubleshooting.

A pod you deploy into your cluster, exec into, and use Claude to inspect resources, read logs, exec into other pods, and diagnose issues.

## Quick start

```bash
# Deploy
kubectl apply -f k8s/manifests.yaml

# Exec in and start Claude
kubectl exec -it deploy/claudetainer -- claude

# Authenticate (first time)
/login
```

## Full YAML

Copy-paste the block below to deploy without cloning the repo.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: claudetainer
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: claudetainer
rules:
  # Read all resources
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
  # Exec into pods
  - apiGroups: [""]
    resources: ["pods/exec", "pods/attach"]
    verbs: ["create"]
  # Read pod logs
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: claudetainer
subjects:
  - kind: ServiceAccount
    name: claudetainer
    namespace: default
roleRef:
  kind: ClusterRole
  name: claudetainer
  apiGroup: rbac.authorization.k8s.io
---
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
          stdin: true
          tty: true
```

## What's included

- Claude CLI
- kubectl
- curl
- jq
- dig
- ping
- vim
- net-tools

## RBAC permissions

The pod's service account is granted a ClusterRole that allows it to:

- Read all resources across all API groups (get, list, watch)
- Exec into and attach to pods
- Read pod logs

## Clean up

If deployed from the repo:

```bash
kubectl delete -f k8s/manifests.yaml
```

If deployed via copy-paste, delete the individual resources:

```bash
kubectl delete deployment claudetainer
kubectl delete clusterrolebinding claudetainer
kubectl delete clusterrole claudetainer
kubectl delete serviceaccount claudetainer
```

## Building from source

```bash
docker build -t claudetainer .
```
