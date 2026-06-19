# Technical Reference — OpenClaw Network Boundary on Kubernetes

## How the Docker Compose stack maps to Kubernetes

### Networks → NetworkPolicies

| Docker network | Role | Kubernetes equivalent |
|---|---|---|
| `net-internal` | openclaw ↔ ollama only; no external routing | `openclaw-egress-to-ollama` + `ollama-ingress-from-openclaw` |
| `net-ingress` | nginx ↔ openclaw reverse proxy | `nginx-egress-to-openclaw` + `openclaw-ingress-from-nginx` |
| `net-proxy` | openclaw → nginx:8080 forward proxy | `openclaw-egress-to-nginx-proxy` + `nginx-ingress-proxy-from-openclaw` |
| `net-telemetry` | nginx → otel-collector (internal only) | `nginx-egress-to-otel` + `otel-ingress-from-nginx` |
| `net-pull` | ollama internet egress for model pulls | `ollama-egress-internet` |

### Volumes → PersistentVolumeClaims

| Compose volume | Purpose | PVC | Default size |
|---|---|---|---|
| `ollama-models` | Model weights | `ollama-models` | 20 Gi |
| `openclaw-state` | OpenClaw config and session state | `openclaw-state` | 1 Gi |
| `otel-data` | JSONL traffic audit log | `otel-data` | 5 Gi |
| `nginx-acme-state` | nginx-acme cert state | Not used — cert-manager owns TLS | — |

### TLS: nginx-acme → cert-manager

The original stack uses `ngx_http_acme_module` inside the nginx container to obtain and renew Let's Encrypt certificates. In Kubernetes, cert-manager is the standard mechanism for the same workflow:

| Compose (nginx-acme) | Kubernetes (cert-manager) |
|---|---|
| `acme_issuer letsencrypt {}` | `ClusterIssuer/letsencrypt-prod` |
| HTTP-01 challenge served by nginx on port 80 | HTTP-01 challenge served by a temporary cert-manager pod via Traefik Ingress |
| Certificate stored in `/var/cache/nginx/acme-letsencrypt` | Certificate stored as Kubernetes `Secret/openclaw-tls` |
| Renewal triggered by nginx-acme module | Renewal triggered by cert-manager when cert is within 30 days of expiry |
| nginx reads `$acme_certificate` / `$acme_certificate_key` | nginx reads `/etc/nginx/tls/tls.crt` / `/etc/nginx/tls/tls.key` (Secret volume mount) |

**Certificate rotation:** When cert-manager renews the certificate it updates the `openclaw-tls` Secret. Kubernetes does not automatically restart pods when mounted Secrets change. To trigger a reload:
- Install [Reloader](https://github.com/stakater/Reloader) and the annotation on the nginx Deployment is already set (`secret.reloader.stakater.com/reload: "openclaw-tls"`).
- Without Reloader, manually restart: `kubectl rollout restart deployment nginx -n openclaw`

## NetworkPolicy CNI requirements

Kubernetes NetworkPolicies require a CNI plugin that enforces them at the node level. Default CNIs by distribution:

| Distribution | Default CNI | NetworkPolicy support |
|---|---|---|
| k3s | Flannel | No — must replace or add a policy enforcer |
| kubeadm | None (install separately) | Depends on chosen CNI |
| k0s | Kube-router | Yes |
| Talos | Flannel | No by default |

### Enabling NetworkPolicies on k3s

**Option A — Install Calico as the CNI (full replacement):**
```bash
curl -sfL https://get.k3s.io | sh -s - \
  --flannel-backend=none \
  --disable-network-policy \
  --cluster-cidr=10.244.0.0/16

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
```

**Option B — Canal (Flannel networking + Calico policy enforcement):**
```bash
curl -sfL https://get.k3s.io | sh -s - \
  --flannel-backend=none \
  --disable-network-policy

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/canal.yaml
```

**Without a policy-capable CNI:** The NetworkPolicy manifests apply without error but have no enforcement effect. The iptables rules inside the openclaw container still enforce kernel-level outbound isolation independently of Kubernetes NetworkPolicies.

## Kernel-level isolation (NET_ADMIN / iptables)

The openclaw container entrypoint applies `iptables-legacy` OUTPUT rules on startup:

```
ACCEPT  lo (loopback)
ACCEPT  ESTABLISHED/RELATED connections
ACCEPT  10.0.0.0/8
ACCEPT  172.16.0.0/12
ACCEPT  192.168.0.0/16
DROP    everything else (default OUTPUT policy)
```

In Kubernetes, all pod-to-pod traffic uses RFC1918 addresses (pod CIDR + service CIDR), so these rules correctly allow traffic to the nginx and ollama Services while blocking direct public internet access.

The container must be granted `NET_ADMIN` capability:
```yaml
securityContext:
  capabilities:
    add:
      - NET_ADMIN
```

If your cluster's PodSecurity admission or OPA/Gatekeeper policy forbids `NET_ADMIN`, the entrypoint logs a warning and continues without kernel isolation. Application-layer routing via `HTTP_PROXY`/`HTTPS_PROXY` still enforces the proxy path.

### How the iptables rules apply in Kubernetes (network namespaces)

A common question: how can a container set `iptables` rules without affecting the node or other workloads? The answer is **Linux network namespaces**.

- **One kernel, partitioned netfilter.** Every node runs a single kernel, and `iptables`/netfilter lives in that kernel — but netfilter state is scoped *per network namespace*, not globally. Each Kubernetes pod gets its own network namespace (shared by all containers in the pod).
- **Pod-scoped enforcement.** The rules the openclaw entrypoint installs land in *that pod's* netns only. They filter egress for the agent pod and are invisible to the node and to every other pod. This is genuine kernel-level enforcement, but its blast radius is exactly one pod.
- **No conflict with kube-proxy / the CNI.** `kube-proxy` and the CNI write their own iptables/eBPF rules for Service VIPs and pod routing, but those live in the **host** network namespace. The CNI sets up the pod's `veth` and routing first; the openclaw entrypoint then layers its `OUTPUT` filter on top, inside the pod netns. The two never collide.
- **Ephemeral, self-healing.** The rules exist only in the pod netns and are re-applied by the entrypoint on every container start. There is no persistent host state to clean up. If the pod reschedules to another node, the rules rebuild themselves there.
- **Scope boundary.** These rules isolate the agent pod's *own* egress. Preventing other pods from bypassing the boundary laterally is a separate concern handled by the Kubernetes NetworkPolicies (enforced by a policy-capable CNI in the host datapath).

The layers therefore map cleanly onto Kubernetes primitives: iptables in the pod netns ensures the agent can only leave through nginx; NetworkPolicies in the CNI prevent lateral bypass; nginx + OpenTelemetry control and observe the one remaining path.

## GPU support for Ollama

GPU is enabled by default in `k8s/05-statefulset-ollama.yaml` (`runtimeClassName: nvidia` + `nvidia.com/gpu: "1"`). The setup below is required on each node that will run the Ollama pod.

### Node setup (single-server k3s)

k3s uses containerd, not Docker. Configure the NVIDIA runtime for containerd:

```bash
# 1. Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit

# 2. Configure containerd (k3s runtime)
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart k3s

# 3. Verify containerd picks up the nvidia runtime
sudo cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml | grep nvidia
```

### NVIDIA device plugin (required for GPU scheduling)

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.0/deployments/static/nvidia-device-plugin.yml
kubectl wait --namespace kube-system --for=condition=ready pod \
  --selector=name=nvidia-device-plugin-ds --timeout=120s
```

### Verify the node exposes GPU resources

```bash
kubectl describe node | grep -A5 "nvidia.com/gpu"
# Expected: Capacity: nvidia.com/gpu: 1 / Allocatable: nvidia.com/gpu: 1
```

### Model sizing by VRAM

| Model | VRAM | Notes |
|---|---|---|
| `qwen2.5:3b` | ~2 GB | Default — very fast |
| `qwen2.5:7b` | ~4.7 GB | Good balance of speed and quality |
| `qwen2.5:14b` | ~8.1 GB | High quality — fits in 12 GB with headroom |
| `llama3.1:8b` | ~4.7 GB | Strong general-purpose model |

### Token limits (demo configuration)

The OpenClaw gateway config (`k8s/01-configmap-openclaw.yaml`) sets `maxTokens: 2048` on the model definition. This caps both input prompt processing and response generation at 2048 tokens per request, which is intentionally conservative for demo use. The Ollama context window (`OLLAMA_CONTEXT_LENGTH: 32768`) is left at 32k so the model retains full context capability; only the per-request limit is reduced. To remove the cap for production use, delete the `maxTokens` line from the configmap and restart the openclaw deployment.

### CPU-only fallback

Remove `runtimeClassName: nvidia` and the `nvidia.com/gpu` resource limit from `k8s/05-statefulset-ollama.yaml`. Reduce memory request/limit as appropriate for CPU inference.

## DNS-01 certificate validation

The default configuration in `k8s/04-certmanager.yaml` uses DNS-01 ACME validation — required when port 80 is not reachable from the internet (internal servers, firewalled clusters). cert-manager creates and deletes a `_acme-challenge` TXT record in your DNS zone to prove domain ownership to Let's Encrypt.

DNS-01 works with any DNS provider supported by cert-manager. The manifest ships with an AWS Route53 solver as the default example. Switch to your provider by replacing the `solvers` block in `04-certmanager.yaml` — commented examples for Cloudflare and GCP Cloud DNS are included in the file.

**Full provider list and configuration reference:** https://cert-manager.io/docs/configuration/acme/dns01/

### Provider credentials

Store your DNS provider's credential in `k8s/04-secret-dns.yaml`:

```yaml
stringData:
  secret-access-key: <your-credential>   # field name matches what 04-certmanager.yaml references
```

Apply it to the cert-manager namespace:
```bash
kubectl apply -f k8s/04-secret-dns.yaml
```

### AWS Route53 example

**Required IAM permissions:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["route53:GetChange"],
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/<YOUR_ZONE_ID>"
    },
    {
      "Effect": "Allow",
      "Action": ["route53:ListHostedZonesByName"],
      "Resource": "*"
    }
  ]
}
```

**Find your hosted zone ID:**
```bash
aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`<your-domain>.`].Id' --output text
```

**Fill in `04-certmanager.yaml`:**

| Field | Value |
|---|---|
| `hostedZoneID` | Route53 hosted zone ID |
| `accessKeyID` | IAM access key ID |
| `email` | Let's Encrypt account email |
| `dnsNames[0]` | Your public domain |

### Cloudflare example

Replace the `route53` solver block in `04-certmanager.yaml` with:

```yaml
solvers:
  - dns01:
      cloudflare:
        email: your-cloudflare-email@example.com
        apiTokenSecretRef:
          name: dns-provider-credentials
          key: api-token
```

Update `04-secret-dns.yaml` — rename the key from `secret-access-key` to `api-token` and set the value to your Cloudflare API token (Zone / DNS / Edit scope):

```yaml
stringData:
  api-token: <your-cloudflare-api-token>
```

### Monitoring DNS-01 challenge progress

```bash
# Watch challenge status (DNS TXT record propagation can take 1–2 minutes)
kubectl describe challenge -n openclaw

# cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Verify TXT record was created (replace with your actual domain)
dig +short TXT _acme-challenge.<your-subdomain>.<your-domain> @8.8.8.8
```

## Restricting outbound destinations

Edit the nginx ConfigMap (`k8s/01-configmap-nginx.yaml`) and uncomment the `map` block in the forward proxy server:

```nginx
map $host $proxy_allowed {
    default              0;
    ~*\.openai\.com      1;
    ~*\.anthropic\.com   1;
}
```

Then uncomment the guard in `location /`:
```nginx
if ($proxy_allowed = 0) { return 403; }
```

Apply the updated ConfigMap and restart nginx:
```bash
kubectl apply -f k8s/01-configmap-nginx.yaml
kubectl rollout restart deployment nginx -n openclaw
```

## Viewing OpenTelemetry spans

```bash
# Copy the JSONL file locally
kubectl cp openclaw/$(kubectl get pod -n openclaw -l app=otel-collector -o jsonpath='{.items[0].metadata.name}'):/data/network-boundary-traffic.jsonl /tmp/spans.jsonl

# Stream in real time
kubectl exec -n openclaw deploy/otel-collector -- tail -f /data/network-boundary-traffic.jsonl

# Pretty-print with jq (if installed on the node)
kubectl exec -n openclaw deploy/otel-collector -- sh -c 'tail -f /data/network-boundary-traffic.jsonl' | jq .
```

Span types emitted by nginx:
- `inbound.request` — HTTPS request arriving at port 19000 (client IP, method, path, status)
- `outbound.request` — HTTP request forwarded through the port 8080 forward proxy (host, method, status)

## Image build matrix

| Image | Source | When to rebuild |
|---|---|---|
| `openclaw-gateway` | `services/openclaw/Dockerfile` | OpenClaw npm package updates, entrypoint changes |
| `openclaw-nginx` | `services/nginx/Dockerfile` | Entrypoint changes (config is injected via ConfigMap — no rebuild needed for config changes) |
| `openclaw-ollama` | `services/ollama/Dockerfile` | Ollama version bump in ARG OLLAMA_VERSION |

For x86 clusters, `ollama/ollama:latest` can be used directly in place of `openclaw-ollama`, removing that image build step.

## Storage sizing guidance

| PVC | Default | Notes |
|---|---|---|
| `ollama-models` | 20 Gi | `qwen2.5:3b` ≈ 2 GB; `llama3.1:8b` ≈ 5 GB; `llama3.1:70b` ≈ 40 GB |
| `openclaw-state` | 1 Gi | Config and device pairing state — rarely exceeds a few MB |
| `otel-data` | 5 Gi | JSONL log with 100 MB rotation; 5 Gi holds 50 rotated files |
