# OpenClaw Network Boundary — Kubernetes Example

This folder contains Kubernetes manifests for deploying the same OpenClaw network boundary stack described in the [parent lab](../README.md) on bare-metal or local Kubernetes (k3s, kubeadm) instead of Docker Compose.

The security model — kernel-level outbound isolation via iptables, nginx as forward proxy and TLS terminator, OpenTelemetry observability — is identical. What changes is how the stack is orchestrated and how TLS certificates are issued: cert-manager handles the full certificate lifecycle via DNS-01 validation, which means **port 80 does not need to be reachable from the internet**.

## Architecture

```
Internet ──HTTPS :19000──▶ nginx LoadBalancer ──▶ openclaw :19000
                                  │
                         OTel inbound spans

openclaw ──iptables + HTTP_PROXY──▶ nginx :8080 (forward proxy) ──▶ Internet
                                          │
                                 OTel outbound spans
                                          │
                               otel-collector :4317
                                          │
                            /data/network-boundary-traffic.jsonl

openclaw ──▶ ollama :11434

(NetworkPolicy manifest - optional - enforced only with Canal/Calico)

cert-manager ──DNS-01──▶ DNS provider TXT record ──▶ LE validation
cert-manager ──writes──▶ openclaw-tls Secret ──▶ nginx /etc/nginx/tls/
```

## Prerequisites

| Requirement | Notes |
|---|---|
| Kubernetes 1.28+ | k3s, kubeadm, or similar bare-metal distribution |
| cert-manager v1.16+ | Installed cluster-wide (see Step 1) |
| Stakater Reloader | Auto-restarts nginx on cert rotation (see Step 1) |
| Container registry | Required for openclaw-gateway and openclaw-nginx images |
| DNS A record | `ACME_DOMAIN` must resolve to the cluster's external IP |
| DNS provider with DNS-01 support | cert-manager supports Route53, Cloudflare, GCP CloudDNS, Azure DNS, and [many others](https://cert-manager.io/docs/configuration/acme/dns01/) |
| Port 19000 reachable | OpenClaw HTTPS endpoint (port 80 not required — DNS-01 validation) |

**GPU:** `k8s/05-statefulset-ollama.yaml` has GPU enabled by default (`runtimeClassName: nvidia`, `nvidia.com/gpu: "1"`). Requires [NVIDIA device plugin](https://github.com/NVIDIA/k8s-device-plugin) and `nvidia-container-toolkit` on the node. A GPU with 12 GB VRAM supports models up to `qwen2.5:14b`. For CPU-only clusters, remove those two fields and reduce memory limits.

## Step 1 — Install cert-manager and Reloader

```bash
# cert-manager (TLS certificate lifecycle)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=120s

# Stakater Reloader (auto-restarts nginx when the TLS Secret is rotated)
kubectl apply -f https://github.com/stakater/Reloader/releases/latest/download/reloader.yaml
```

## Step 2 — Build and push custom images

Navigate to the parent lab directory and build the custom images:

```bash
cd ..   # openclaw_network_boundary/

export REGISTRY=your-registry.example.com/yourorg

# Kubernetes requires the gateway to bind on all interfaces, not just loopback.
# Patch the config template before building:
sed -i 's/"mode": "local"/"mode": "local",\n    "bind": "lan"/' \
  services/openclaw/config/openclaw.json.template

# OpenClaw gateway
docker build -t ${REGISTRY}/openclaw-gateway:latest services/openclaw/
docker push ${REGISTRY}/openclaw-gateway:latest

# nginx (OTel module + custom entrypoint — config is injected via ConfigMap)
docker build -t ${REGISTRY}/openclaw-nginx:latest services/nginx/
docker push ${REGISTRY}/openclaw-nginx:latest

# Ollama (x86 build; for arm64/Jetson use --platform linux/arm64)
docker build -t ${REGISTRY}/openclaw-ollama:latest services/ollama/
docker push ${REGISTRY}/openclaw-ollama:latest
```

> For x86 clusters you can substitute `ollama/ollama:latest` for `openclaw-ollama` and skip that build.

## Step 3 — Configure

### 3a. Update image references

Replace `YOUR_REGISTRY` in the deployment files with your registry path:

```bash
# Linux/macOS
sed -i "s|YOUR_REGISTRY|${REGISTRY}|g" k8s/05-deployment-openclaw.yaml k8s/05-deployment-nginx.yaml k8s/05-statefulset-ollama.yaml

# Windows (PowerShell)
$reg = "your-registry.example.com/yourorg"
@("k8s/05-deployment-openclaw.yaml","k8s/05-deployment-nginx.yaml","k8s/05-statefulset-ollama.yaml") | ForEach-Object {
    (Get-Content $_) -replace "YOUR_REGISTRY", $reg | Set-Content $_
}
```

### 3b. Configure DNS-01 certificate issuance

OpenClaw uses DNS-01 ACME validation so TLS certificates are issued without needing port 80 open. cert-manager supports many DNS providers — choose the one that manages your domain.

**Supported providers include:** AWS Route53, Cloudflare, GCP CloudDNS, Azure DNS, DigitalOcean, and [more](https://cert-manager.io/docs/configuration/acme/dns01/).

#### Step 1 — Create the DNS provider credentials Secret

Edit `k8s/04-secret-dns.yaml` and fill in your provider's credential:

```yaml
stringData:
  secret-access-key: <your-provider-secret>   # AWS: IAM secret access key
                                               # Cloudflare: API token (rename key to "api-token")
```

Apply it:
```bash
kubectl apply -f k8s/04-secret-dns.yaml
```

#### Step 2 — Configure the ClusterIssuer

Edit `k8s/04-certmanager.yaml`. The default solver block is AWS Route53 — replace it with the block for your provider. The file contains commented examples for Route53, Cloudflare, and GCP Cloud DNS. Full examples for all providers are at [cert-manager DNS-01 docs](https://cert-manager.io/docs/configuration/acme/dns01/).

| Field | Value |
|---|---|
| `email` | Your Let's Encrypt account email |
| `dnsNames[0]` | Your public domain (e.g. `your-subdomain.your-domain.com`) |
| Provider fields | Zone ID, access key, API token, etc. — provider-specific |

**AWS Route53 — find your hosted zone ID:**
```bash
aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`<your-domain>.`].Id' --output text
```

**Cloudflare — required token scopes:**
- Zone / DNS / Edit (scoped to your zone)

Apply the issuer:
```bash
kubectl apply -f k8s/04-certmanager.yaml
```

### 3c. Fill in the application Secret

Edit `k8s/02-secret.yaml` and replace all placeholder values:

| Key | Description |
|---|---|
| `GATEWAY_TOKEN` | Random token for OpenClaw UI authentication — generate with `openssl rand -hex 32` |
| `OLLAMA_MODEL` / `OLLAMA_CHAT_MODEL` | Model to pull and serve (e.g. `qwen2.5:3b`) |
| `ACME_DOMAIN` | Public domain pointing at the cluster's external IP |
| `ACME_EMAIL` | Email for Let's Encrypt account registration |
| `OPENCLAW_HOST` | Same as `ACME_DOMAIN` (used in CORS headers) |
| `OPENCLAW_HOST_PORT` | External port for the OpenClaw HTTPS endpoint (default `19000`) |

### 3d. Adjust storage class (if needed)

`k8s/03-pvc.yaml` uses `storageClassName: local-path` (k3s default).  
For kubeadm, replace with your cluster's provisioner class:

```bash
kubectl get storageclass
```

## Step 4 — Deploy

**Recommended: step-by-step** (easier to diagnose failures):

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmap-nginx.yaml -f k8s/01-configmap-otel.yaml
kubectl apply -f k8s/02-secret.yaml
kubectl apply -f k8s/03-pvc.yaml

# DNS provider credentials for cert-manager DNS-01 (cert-manager namespace)
kubectl apply -f k8s/04-secret-dns.yaml

# cert-manager ClusterIssuer + Certificate (wait for CRDs to be ready first)
kubectl apply -f k8s/04-certmanager.yaml

# Start the LLM backend first — openclaw waits for it to be ready
kubectl apply -f k8s/05-statefulset-ollama.yaml
kubectl apply -f k8s/05-deployment-otel.yaml

# Start the gateway and ingress layer
kubectl apply -f k8s/05-deployment-openclaw.yaml
kubectl apply -f k8s/05-deployment-nginx.yaml
kubectl apply -f k8s/06-services.yaml

# Apply NetworkPolicies last (requires policy-capable CNI — see docs/technical.md)
kubectl apply -f k8s/07-networkpolicies.yaml
```

**Or with Kustomize:**

```bash
kubectl apply -k k8s/
```

## Step 5 — Watch the rollout

```bash
# All pods in the namespace
kubectl get pods -n openclaw -w

# Ollama model pull progress (takes 5–15 min on first start)
kubectl logs -n openclaw -l app=ollama -f

# nginx startup and cert issuance
kubectl logs -n openclaw -l app=nginx -f

# cert-manager certificate status
kubectl describe certificate openclaw-tls -n openclaw
kubectl get certificaterequest -n openclaw
```

## Step 6 — Verify

```bash
# All pods Running
kubectl get pods -n openclaw

# nginx external IP assigned
kubectl get svc -n openclaw nginx

# TLS certificate issued
kubectl get secret openclaw-tls -n openclaw
```

Open `https://<ACME_DOMAIN>:19000` in your browser. Enter the `GATEWAY_TOKEN` when prompted.

## Step 7 — Pair a device

```bash
# List pending pairing requests
kubectl exec -n openclaw deploy/openclaw \
  -- sh -c 'GATEWAY_TOKEN=<your-token> openclaw devices list'

# Approve a request
kubectl exec -n openclaw deploy/openclaw \
  -- sh -c 'GATEWAY_TOKEN=<your-token> openclaw devices approve <request-id>'
```

## Observing traffic

```bash
# Outbound connections through the nginx forward proxy
kubectl logs -n openclaw -l app=nginx -f

# OpenTelemetry spans (inbound + outbound)
kubectl exec -n openclaw deploy/otel-collector \
  -- tail -f /data/network-boundary-traffic.jsonl

# Verify iptables isolation inside openclaw container
kubectl logs -n openclaw -l app=openclaw | grep iptables
```

## Troubleshooting

| Symptom | Check |
|---|---|
| nginx pod `CrashLoopBackOff` | `kubectl logs -n openclaw -l app=nginx` — likely a missing env var or TLS Secret not yet created |
| TLS Secret `openclaw-tls` missing | cert-manager hasn't issued the cert yet. Check: `kubectl describe certificate openclaw-tls -n openclaw` and `kubectl describe challenge -n openclaw` |
| DNS-01 challenge fails | Check provider credentials: `kubectl describe secret dns-provider-credentials -n cert-manager`. Verify permissions and zone/domain config in `04-certmanager.yaml`. |
| cert-manager can't read dns-provider-credentials | Secret must be in the `cert-manager` namespace, not `openclaw`. Verify: `kubectl get secret dns-provider-credentials -n cert-manager` |
| Ollama pod never becomes Ready | Model pull in progress — can take 15+ min. Check: `kubectl logs -n openclaw -l app=ollama -f` |
| openclaw `iptables-legacy unavailable` warning | NET_ADMIN capability missing or not supported by cluster policy. Application-layer proxy routing still works. |
| NetworkPolicies have no effect | CNI does not support NetworkPolicies (Flannel default). See [docs/technical.md](docs/technical.md) for enabling Canal/Calico. |
| PVC `Pending` | StorageClass not found — check `kubectl get storageclass` and update `03-pvc.yaml` |

## Reference

- [Technical reference](docs/technical.md) — architecture details, NetworkPolicy CNI requirements, GPU setup, DNS-01 provider configuration
- [Parent lab README](../README.md) — Docker Compose version of the same stack
- [cert-manager DNS-01 docs](https://cert-manager.io/docs/configuration/acme/dns01/) — full provider list

## License

Apache 2.0 — Copyright (c) 2026 markosluga
