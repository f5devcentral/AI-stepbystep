# OpenClaw Network Boundary — Technical Reference

## Overview

A self-contained Docker Compose stack that wraps an OpenClaw AI gateway and an Ollama LLM backend inside a secure network envelope. All inbound HTTPS traffic is proxied and traced by nginx. All outbound traffic from OpenClaw is controlled by nginx's forward proxy — nginx establishes CONNECT tunnels for HTTPS (sees destination host:port, not content) and proxies HTTP requests directly. Both paths emit OpenTelemetry spans to a local collector that writes JSON Lines to a persistent volume.

---

## Architecture

```
Internet ──HTTPS──▶ nginx :OPENCLAW_HOST_PORT (TLS termination) ──▶ openclaw :19000
                         │
                   OTel inbound spans (method, path, status, client IP)

openclaw ──iptables enforced──▶ nginx :8080 (forward proxy) ──▶ Internet
                                     │
                           OTel outbound spans
                           HTTPS: outbound.connect (host:port only)
                           HTTP:  outbound.request (host, method, status)
                                     │
                         otel-collector :4317
                                     │
                         /data/network-boundary-traffic.jsonl

openclaw ──────────────────────────────────────────────────────▶ ollama :11434
                        (net-internal, no external routing)
```

---

## Networks

| Network | Members | Notes |
|---|---|---|
| `net-internal` | openclaw, ollama | `internal: true` — LLM inference path only |
| `net-ingress` | nginx, openclaw | nginx exposes `OPENCLAW_HOST_PORT` |
| `net-proxy` | openclaw, nginx | outbound forward proxy path |
| `net-telemetry` | nginx, otel-collector | `internal: true` — OTel spans only |
| `net-pull` | ollama, nginx | internet access for model pulls and ACME challenges |

---

## Containers

### openclaw
- **Image**: custom build from `./services/openclaw`
- **Role**: AI gateway; handles browser pairing, token auth, and forwards LLM requests to Ollama
- **Auth**: `GATEWAY_TOKEN` env var — required for all API and UI access
- **Outbound proxy**: routes all HTTP/HTTPS via nginx forward proxy (`HTTP_PROXY=http://nginx:8080`, `HTTPS_PROXY=http://nginx:8080`)
- **State**: `/root/.openclaw` persisted in `openclaw-state` volume (pairing data, config)
- **Exposes**: port `19000` to `net-ingress`

### ollama
- **Image**: custom build from `./services/ollama`
- **Role**: local LLM inference; serves the OpenAI-compatible API on port `11434`
- **Runtime**: `OLLAMA_RUNTIME` — `nvidia` for Jetson/NVIDIA GPU; empty for CPU/x86
- **Model pull**: pulls `OLLAMA_MODEL` on first start; stored in `ollama-models` volume
- **Tuning**: flash attention enabled; KV cache type `q8_0`; context length `32768`
- **Networks**: `net-internal` (openclaw access) + `net-pull` (model downloads)

### nginx
- **Image**: `nginx:1.31.0-otel` — ships with `ngx_otel_module`, `ngx_http_acme_module`, and `ngx_http_proxy_connect_module`
- **Inbound role**: terminates TLS on port `OPENCLAW_HOST_PORT`; Let's Encrypt cert issued and renewed natively by `ngx_http_acme_module` via HTTP-01 challenge; port 80 must be publicly reachable
- **Outbound role**: forward proxy on port `8080`; openclaw routes through `HTTP_PROXY` / `HTTPS_PROXY`
  - HTTPS CONNECT tunnels: nginx relays TCP between openclaw and the destination; sees host:port only, does not decrypt content (`proxy_connect` module)
  - HTTP forward proxy: full request visible to nginx; host, method, status recorded in spans
- **Cert state**: `nginx-acme-state` named volume at `/var/cache/nginx/acme-letsencrypt/`; persists account key and cert across container restarts
- **OTel inbound**: `otel_exporter { endpoint otel-collector:4317; }` + `otel_trace on`; span name `inbound.request`
- **OTel outbound**: span name `outbound.connect` (HTTPS tunnels) or `outbound.request` (HTTP)
- **Startup**: renders nginx.conf from template, starts nginx; acme module issues cert on first request and handles all subsequent renewals in-process
- **Networks**: `net-ingress` + `net-proxy` + `net-telemetry` + `net-pull`

### otel-collector
- **Image**: `otel/opentelemetry-collector-contrib:latest`
- **Receiver**: OTLP gRPC on `:4317`
- **Exporter**: file exporter → `/data/network-boundary-traffic.jsonl` with rotation (100 MB / 30 days)
- **User**: runs as root to write to the named Docker volume

---

## Volumes

| Volume | Purpose |
|---|---|
| `otel-data` | `network-boundary-traffic.jsonl` — all spans from inbound and outbound paths |
| `nginx-acme-state` | nginx-acme module state (account key, cert, order data) at `/var/cache/nginx/acme-letsencrypt/` |
| `openclaw-state` | OpenClaw pairing data and runtime config (`/root/.openclaw`) |
| `ollama-models` | Downloaded Ollama model weights (`/data/models/ollama/models`) |

---

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `GATEWAY_TOKEN` | yes | — | Authentication token for OpenClaw UI and API |
| `OPENCLAW_USER` | no | (empty) | Optional username hint for OpenClaw |
| `OPENCLAW_HOST` | yes | — | IP or hostname of the Docker host (used in CORS origins) |
| `OPENCLAW_HOST_PORT` | no | `19000` | Host port nginx exposes for inbound HTTPS |
| `OLLAMA_MODEL` | no | `qwen2.5:3b` | Model pulled on first start and used by OpenClaw |
| `OLLAMA_CHAT_MODEL` | no | `qwen2.5:3b` | Chat model variant (can differ from OLLAMA_MODEL) |
| `OLLAMA_RUNTIME` | no | `nvidia` | Docker runtime — `nvidia` for Jetson/GPU, empty for CPU |
| `ACME_DOMAIN` | yes | — | Domain for Let's Encrypt certificate; must have DNS A record pointing to host |
| `ACME_EMAIL` | yes | — | Email for Let's Encrypt registration and expiry notices |

---

## TLS Termination

nginx terminates TLS on port `OPENCLAW_HOST_PORT` (default 19000). Certificates are issued and renewed by the [nginx-acme module](https://github.com/nginx/nginx-acme) (`ngx_http_acme_module`) running natively inside the nginx process. The module state (account key, cert, order data) is persisted in the `nginx-acme-state` Docker volume so container restarts do not re-issue unnecessarily.

**Port 80 must be publicly reachable** from the internet for the HTTP-01 challenge to succeed.

### Certificate flow

```
nginx (ngx_http_acme_module)
    │
    ├── HTTP-01 challenge: Let's Encrypt GETs /.well-known/acme-challenge/<token>
    │   via port 80 — module serves the response directly, no external tool needed
    │
    ├── On success: cert loaded into nginx memory ($acme_certificate variable)
    │
    └── State persisted at /var/cache/nginx/acme-letsencrypt/ (nginx-acme-state volume)
         ├── account key
         ├── certificate + chain
         └── order metadata
```

### Renewal

The module monitors certificate expiry in-process. When the cert approaches expiry it re-runs the HTTP-01 challenge and updates the in-memory certificate without restarting nginx or dropping connections. No cron jobs, external processes, or nginx reloads are required.

### DNS-01 alternative

If port 80 cannot be exposed, the acme.sh DNS-01 approach is documented in [docs/dns-acme.md](dns-acme.md). DNS-01 supports AWS Route53, Cloudflare, and Google Cloud DNS.

---

## Forward Proxy

nginx listens on port `8080` as a forward proxy, accessible only from `net-proxy` (openclaw). openclaw is configured with `HTTP_PROXY=http://nginx:8080` and `HTTPS_PROXY=http://nginx:8080`. iptables inside the openclaw container blocks all direct internet access (public IPs), so the nginx forward proxy is the only outbound path.

### HTTPS CONNECT tunneling

When openclaw connects to an HTTPS endpoint, it sends a `CONNECT host:443 HTTP/1.1` request to nginx. nginx (via `ngx_http_proxy_connect_module`) establishes a TCP relay to the destination. openclaw performs the TLS handshake directly with the destination server — nginx is not in the TLS session and cannot see the payload. This means:

- No CA cert injection required in openclaw
- Full TLS integrity between openclaw and the destination
- nginx sees only: source IP, destination host, destination port, connection status

### HTTP forward proxy

For plain HTTP outbound requests, nginx proxies the full request. Host, method, path, and status are available in both the nginx access log and OTel spans.

### Access control

By default, all outbound destinations are permitted. To restrict openclaw to specific hosts, edit the `map` block in `services/nginx/nginx.conf.template`:

```nginx
map $host $proxy_allowed {
    default              0;
    ~*\.openai\.com      1;
    ~*\.anthropic\.com   1;
}
```

Add the guard in `location /`:

```nginx
if ($proxy_allowed = 0) { return 403; }
```

Rebuild nginx after changes: `docker compose up -d --build nginx`

---

## OTel Span Reference

### `inbound.request` (nginx — inbound reverse proxy)
| Attribute | Value |
|---|---|
| `http.client_ip` | Client remote address |
| `http.method` | HTTP method |
| `http.path` | Request URI |
| `http.status` | Response status code |

### `outbound.connect` (nginx — HTTPS CONNECT tunnel)
| Attribute | Value |
|---|---|
| `outbound.host` | Destination hostname (from CONNECT request) |
| `outbound.port` | Destination port |

### `outbound.request` (nginx — HTTP forward proxy)
| Attribute | Value |
|---|---|
| `outbound.host` | Destination hostname |
| `outbound.method` | HTTP method |
| `outbound.status` | Response status code |

---

## Usage

### Start the stack
```bash
cp .env.example .env
# fill in .env — at minimum: GATEWAY_TOKEN, OPENCLAW_HOST, ACME_DOMAIN, ACME_EMAIL
docker compose up -d
```

### View live traffic spans
```bash
docker exec otel-collector sh -c "tail -f /data/network-boundary-traffic.jsonl"
```

### Watch outbound connections in real time
```bash
docker compose logs -f nginx
```

### Check status
```bash
docker compose ps
```
