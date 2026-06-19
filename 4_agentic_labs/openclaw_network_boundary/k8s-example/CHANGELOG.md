# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-06-19

### Changed
- `k8s/04-secret-route53.yaml` renamed to `k8s/04-secret-dns.yaml` — generalized to support any cert-manager DNS-01 provider; placeholder renamed from `REPLACE_AWS_SECRET_ACCESS_KEY` to `REPLACE_DNS_PROVIDER_SECRET`; added Cloudflare and generic provider guidance in comments
- `k8s/04-certmanager.yaml` — removed provider-specific and identifying details from comments; added commented solver examples for Cloudflare and GCP Cloud DNS alongside the existing Route53 example; Secret reference updated to `dns-provider-credentials`
- `k8s/kustomization.yaml` — updated filename reference and step-by-step comments to match renamed secret file
- `k8s/05-statefulset-ollama.yaml` — generalized GPU comment to remove hardware-specific model reference
- `README.md` — removed identifying domain and profile references; rewrote Step 3b as a provider-agnostic DNS-01 configuration guide with Route53 and Cloudflare examples; architecture diagram updated to show generic DNS provider
- `docs/technical.md` — removed identifying domain and profile references; restructured DNS-01 section as a multi-provider guide (Route53, Cloudflare) with generic placeholder commands; generalized GPU sizing table heading

## [0.1.5] - 2026-06-18

### Fixed

- `k8s/01-configmap-openclaw.yaml` Max token tuning
- `k8s/01-configmap-otel.yaml` Log collection fix
- Updated documentation

## [0.1.4] - 2026-06-18

### Fixed
- `k8s/07-networkpolicies.yaml`: removed `openclaw-egress-internet` NetworkPolicy — direct internet egress from the openclaw pod is no longer needed since all outbound traffic routes through the nginx forward proxy; previously this policy allowed openclaw to bypass the proxy for direct HTTPS
- `k8s/01-configmap-nginx.yaml`: enabled HTTP CONNECT tunneling using nginx 1.31's built-in `ngx_http_tunnel_module` (`tunnel_pass;` with no args defaults to `$host:$request_port`); no third-party `ngx_http_proxy_connect_module` patch needed
- `k8s/01-configmap-nginx.yaml`: added hostname allowlist map (`$proxy_allowed`) and 403 guard to the forward proxy — restricts outbound CONNECT tunnels to permitted domains only; added `html.duckduckgo.com` to the allowlist (web search was returning 403 because the DuckDuckGo HTML endpoint uses a separate subdomain)
- `k8s/05-deployment-openclaw.yaml`: added `HTTPS_PROXY=http://nginx:8080` so Node.js undici routes HTTPS requests through nginx CONNECT tunnel; previously only `HTTP_PROXY` was set
- `k8s/05-deployment-openclaw.yaml`: added `OPENCLAW_PROXY_ACTIVE=1` and `OPENCLAW_PROXY_URL=http://nginx:8080` — openclaw's strict-mode `web_fetch` tool bypasses `HTTP_PROXY`/`HTTPS_PROXY` by design (SSRF protection); setting `OPENCLAW_PROXY_ACTIVE=1` activates the internal managed-proxy routing path which forces all fetch requests (including strict-mode) through the env proxy; without this, `web_fetch` timed out while `web_search` worked
- `k8s/01-configmap-openclaw.yaml`: new ConfigMap overriding the baked-in openclaw config template to enable DuckDuckGo web search (`tools.web.search.provider: duckduckgo`) and web-readability fetch provider

## [0.1.3] - 2026-06-16

### Added
- `docs/cncf-blog-post.md`: CNCF-style blog post positioning NGINX (traffic control) and OpenTelemetry (audit/observability) as the twin cores of the AI agent network boundary, with a section explaining how pod-scoped iptables rules apply in Kubernetes via network namespaces, and a "Testing the Design" walkthrough validating the full Kubernetes/NGINX/Ollama/OpenClaw stack end-to-end
- `docs/kubecon-cfp-submission.md`: KubeCon + CloudNativeCon CFP submission (Security + Identity track, 25-min short session) with abstract, description, live demo plan, and speaker bio

### Changed
- `docs/technical.md`: added "How the iptables rules apply in Kubernetes (network namespaces)" subsection clarifying pod-netns scoping, non-conflict with kube-proxy/CNI host rules, and ephemeral self-healing behavior

## [0.1.2] - 2026-05-27

### Fixed
- `openclaw-gateway` image template: added `trustedProxies: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]` — k3s assigns pod IPs from `10.42.0.0/16`; without the `10.0.0.0/8` range the gateway logs "Proxy headers detected from untrusted address" and treats every nginx-proxied connection as non-local, blocking access
- `openclaw-gateway` image template: added `gateway.controlUi.dangerouslyDisableDeviceAuth: true` — when the Control UI is accessed through a reverse proxy, `X-Forwarded-For` headers cause `isLocalDirectRequest()` to return `false`, which triggers the ECDSA device-pairing flow; that flow requires the openclaw CLI and cannot be completed from a browser alone; this flag bypasses device pairing for the Control UI while keeping token authentication intact
- `README.md`: updated architecture diagram label to clarify NetworkPolicy manifest is optional and enforced only if using cni like Canal/Calico

## [0.1.1] - 2026-05-26

### Fixed
- `openclaw-gateway` image template: added `"bind": "lan"` so the gateway listens on `0.0.0.0:19000` instead of `127.0.0.1:19000` — required for Kubernetes liveness/readiness probes and nginx reverse proxy to reach the pod IP
- `k8s/01-configmap-otel.yaml`: added `health_check` extension (HTTP on port 13133) to the OTel Collector config so the readiness probe can succeed
- `k8s/05-deployment-otel.yaml`: changed otel-collector readiness probe from gRPC (port 4317) to HTTP (`GET /` on port 13133) — gRPC health protocol is not implemented by default in otel-collector-contrib
- `README.md`: added `sed` patch step in the image build instructions to apply `bind: lan` before building

## [0.1.0] - 2026-05-25

### Added
- Initial deployment test completed
- DNS-01 ACME challenge via AWS Route53 (`k8s/04-secret-route53.yaml` + updated `k8s/04-certmanager.yaml`) — enables TLS certificate issuance without requiring port 80 to be reachable from the internet - this can be changed to add any DNS provider with DNS-01 capability
- NVIDIA GPU support enabled by default in Ollama StatefulSet (`runtimeClassName: nvidia`, `nvidia.com/gpu: "1"`)
- Official `ollama/ollama:latest` image used for x86 GPU deployments (no custom build required)

### Changed
- `k8s/kustomization.yaml`: Added `04-secret-route53.yaml` to resource list; updated step-by-step comments

## [0.0.1] - 2026-05-25

### Added
- Initial Kubernetes manifests for deploying the OpenClaw network boundary stack
- Namespace, ConfigMaps, Secret template, PVCs, Deployments, Services, NetworkPolicies
- cert-manager integration (ClusterIssuer + Certificate) substituting what the nginx-acme module did in the source
- Modified nginx configuration for Kubernetes: cert-manager-managed TLS, OTel spans retained
- Ollama StatefulSet with optional NVIDIA GPU RuntimeClass support
- Kustomize overlay structure for environment customization
- Full deployment guide in README.md
- Technical reference in docs/technical.md
- Nothing is tested, once deployment is tested change version to 0.1.0
