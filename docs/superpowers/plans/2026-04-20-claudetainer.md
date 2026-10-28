# Claudetainer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Kubernetes-ready Docker image with Claude CLI and kubectl for interactive cluster troubleshooting.

**Architecture:** A Dockerfile produces a Debian-slim image with Node.js, Claude CLI, and kubectl. Kubernetes manifests provide a Deployment, ServiceAccount, and cluster-wide read/exec RBAC. A GitHub Actions workflow builds and pushes to GHCR on every push to main.

**Tech Stack:** Docker, Kubernetes YAML, GitHub Actions, Node.js 22, Claude CLI (`@anthropic-ai/claude-code`), kubectl

---

## File Structure

```
claudetainer/
├── Dockerfile
├── k8s/
│   └── manifests.yaml          # All K8s resources in one file
├── .github/
│   └── workflows/
│       └── build-push.yml      # CI: build + push to GHCR
├── .dockerignore
├── README.md
└── docs/superpowers/           # Design docs (already exist)
```

---

### Task 1: Dockerfile

**Files:**
- Create: `Dockerfile`
- Create: `.dockerignore`

- [ ] **Step 1: Create .dockerignore**

```
docs/
k8s/
.github/
.git/
README.md
```

- [ ] **Step 2: Write the Dockerfile**

```dockerfile
FROM debian:bookworm-slim

# Avoid interactive prompts during install
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    jq \
    less \
    vim-tiny \
    dnsutils \
    net-tools \
    iputils-ping \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' > /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update && apt-get install -y --no-install-recommends kubectl \
    && rm -rf /var/lib/apt/lists/*

# Install Claude CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user
RUN useradd -m -s /bin/bash claude

# Switch to non-root user
USER claude
WORKDIR /home/claude

# Keep the container alive
CMD ["sleep", "infinity"]
```

- [ ] **Step 3: Build locally to verify**

Run: `docker build -t claudetainer:test .`
Expected: Successful build, no errors.

- [ ] **Step 4: Verify the image works**

Run: `docker run --rm claudetainer:test kubectl version --client -o json | jq .clientVersion.gitVersion`
Expected: Prints a kubectl version string like `"v1.32.x"`

Run: `docker run --rm claudetainer:test claude --version`
Expected: Prints a Claude CLI version string.

- [ ] **Step 5: Commit**

```bash
git add Dockerfile .dockerignore
git commit -m "feat: add Dockerfile with Claude CLI, kubectl, and troubleshooting tools"
```

---

### Task 2: Kubernetes Manifests

**Files:**
- Create: `k8s/manifests.yaml`

- [ ] **Step 1: Write the combined manifest file**

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

- [ ] **Step 2: Validate YAML syntax**

Run: `kubectl apply --dry-run=client -f k8s/manifests.yaml`
Expected: All 4 resources validated successfully (serviceaccount, clusterrole, clusterrolebinding, deployment).

- [ ] **Step 3: Commit**

```bash
git add k8s/manifests.yaml
git commit -m "feat: add Kubernetes manifests with RBAC and deployment"
```

---

### Task 3: GitHub Actions Workflow

**Files:**
- Create: `.github/workflows/build-push.yml`

- [ ] **Step 1: Write the workflow**

```yaml
name: Build and Push

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=latest
            type=sha,prefix=

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

- [ ] **Step 2: Validate workflow syntax**

Run: `cat .github/workflows/build-push.yml | python3 -c "import sys,yaml;yaml.safe_load(sys.stdin)" && echo "Valid YAML"`
Expected: `Valid YAML`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/build-push.yml
git commit -m "ci: add GitHub Actions workflow to build and push to GHCR"
```

---

### Task 4: README with Quick-Start and Full YAML

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

The README should include:

1. **Title and description** — what claudetainer is
2. **Quick start** — 3 commands: apply, exec, login
3. **Full YAML** — a single fenced code block containing ALL Kubernetes resources (ServiceAccount, ClusterRole, ClusterRoleBinding, Deployment) so the user can copy-paste without cloning the repo
4. **Clean up** — how to remove everything
5. **Building from source** — how to build the Docker image locally

The full YAML block in the README is identical to `k8s/manifests.yaml` — it's duplicated intentionally so users can copy-paste from the README without needing to clone.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with usage instructions and full copy-paste YAML"
```

---

### Task 5: Create GitHub Repo and Push

- [ ] **Step 1: Create the repo on GitHub**

```bash
gh repo create matopst/claudetainer --public --source=. --remote=origin --description "Claude CLI in Kubernetes for cluster troubleshooting"
```

- [ ] **Step 2: Push to main**

```bash
git push -u origin main
```

Expected: All commits pushed. GitHub Actions workflow triggers automatically and builds the image.

- [ ] **Step 3: Verify the workflow ran**

Check: `gh run list --repo matopst/claudetainer`
Expected: A workflow run in progress or completed.
