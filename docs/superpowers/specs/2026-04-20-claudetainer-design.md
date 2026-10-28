# Claudetainer — Design Spec

**Date**: 2026-04-20
**Status**: Approved

## Purpose

A Kubernetes-native troubleshooting pod that runs Claude CLI with the read access of an existing ServiceAccount. Allows a user to `kubectl exec` into the pod, authenticate via `/login`, and use Claude to inspect resources, read logs, and diagnose cluster issues.

## Container Image

- **Base**: `debian:bookworm-slim`
- **Runtime**: Node.js 22 LTS (via NodeSource)
- **Claude CLI**: `@anthropic-ai/claude-code` via npm (latest)
- **kubectl**: Latest stable from official Kubernetes apt repo
- **Troubleshooting tools**: `curl`, `jq`, `less`, `vim-tiny`, `dnsutils`, `net-tools`, `iputils-ping`, `openssl`, `netcat`, `traceroute`, `procps`
- **Cluster viewing tools**: `k9s`, `stern`, `helm`
- **User**: Non-root `claude` user
- **Entrypoint**: `sleep infinity` (keeps pod alive for exec)
- **Architecture**: `linux/amd64` only

## Kubernetes Manifests

Only a Deployment is shipped, in the `default` namespace. No ServiceAccount or RBAC is created; the Deployment references an existing read-only ServiceAccount.

### Deployment (`claudetainer`)
- 1 replica
- Image: `ghcr.io/matopst/claudetainer:latest`
- ServiceAccount: existing read-only ServiceAccount (`serviceAccountName`, adjust to match)
- Runs as non-root `claude` user
- Resources:
  - Requests: 512Mi memory, 500m CPU
  - Limits: 2Gi memory, 2 CPU
- No liveness/readiness probes

## CI/CD

### GitHub Actions (`.github/workflows/build-push.yml`)
- **Triggers**: Push to `main`, manual `workflow_dispatch`
- **Steps**:
  1. Checkout
  2. Login to GHCR with `GITHUB_TOKEN`
  3. Build with Docker Buildx (amd64)
  4. Tag as `ghcr.io/matopst/claudetainer:latest` and `:$SHA`
  5. Push to GHCR

## Usage

```bash
# Deploy
kubectl apply -f k8s/

# Exec in and start Claude
kubectl exec -it deploy/claudetainer -- claude

# Clean up
kubectl delete -f k8s/
```

## Authentication

No pre-configured API key. The user runs `/login` inside the Claude CLI session, which provides a URL for browser-based OAuth. Auth token is ephemeral — lost on pod restart (accepted trade-off for simplicity).

## Repository

- GitHub: `matopst/claudetainer`
- Registry: `ghcr.io/matopst/claudetainer`
