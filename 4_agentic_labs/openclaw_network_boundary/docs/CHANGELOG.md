# Changelog

## [2.0.0] — 2026-05-25

### Changed
- Replaced mitmproxy with nginx forward proxy as the outbound traffic control mechanism
  - nginx 1.31.1-otel is the base image; HTTP forward proxy works natively on port 8080
  - Plain HTTP outbound requests are still proxied and visible to nginx (host, method, status)
  - openclaw now routes via `HTTP_PROXY=http://nginx:8080` / `HTTPS_PROXY=http://nginx:8080`
  - Access control (allow/deny by destination host) is enforced at nginx; commented example allowlist pattern included in `nginx.conf.template`
  - OTel spans: `outbound.connect` (HTTPS tunnels — host and port) and `outbound.request` (HTTP — host, method, status); rich content-level attributes from mitmproxy are no longer available by design

### Removed
- `mitmproxy` container and `services/mitmproxy/` directory
- `mitm-certs` named volume — no CA cert injection required; openclaw trusts the destination server's certificate directly
- `NODE_EXTRA_CA_CERTS` environment variable from the openclaw service
- mitmproxy web UI (was exposed on host port 8081)
- openclaw entrypoint step that waited for the mitmproxy CA cert to appear

### Added
- nginx forward proxy server block on port 8080 in `nginx.conf.template`
  - `proxy_connect` for HTTPS CONNECT tunneling
  - OTel instrumentation via `ngx_otel_module` for both HTTP and HTTPS outbound connections
  - Documented allowlist pattern for restricting outbound destinations by hostname

## [1.0.2] — 2026-04-23

### Changed
- Replaced the multi-stage Rust-based nginx Dockerfile with a single `FROM nginx:1.30.0-otel` — the official otel image ships with both `ngx_otel_module` and `ngx_http_acme_module` pre-installed, eliminating the builder stage, Rust toolchain, and custom apt source entirely

## [1.0.1] — 2026-04-23

### Changed
- Updated nginx base image from `nginx:1.27` to `nginx:1.30.0` (released 2026-04-14)

## [1.0.0] — 2026-04-22

Initial release.

### Added
- OpenClaw AI gateway running behind a secure network boundary
- nginx inbound reverse proxy with TLS termination via the native [nginx-acme module](https://github.com/nginx/nginx-acme) (`ngx_http_acme_module`)
  - HTTP-01 challenge handled entirely in-process — no external tooling, no renewal loop, no DNS provider credentials required
  - Multi-stage Dockerfile: builder stage compiles the Rust module against the exact nginx version; final image contains no build toolchain
  - Cert state persisted in `nginx-acme-state` named volume — container restarts do not re-issue
  - DNS-01 alternative (acme.sh, AWS Route53 / Cloudflare / Google Cloud DNS) documented in [docs/dns-acme.md](dns-acme.md)
- mitmproxy outbound MITM proxy with OTel addon emitting `outbound.request` and `outbound.tls_error` spans
- Kernel-level outbound isolation via iptables inside the openclaw container (`cap_add: NET_ADMIN`)
- Ollama LLM backend — nvidia runtime on Jetson (arm64 + NVIDIA), CPU/empty on x86
- otel-collector writing all inbound and outbound spans to `/data/network-boundary-traffic.jsonl` with rotation
- Five-container Docker Compose stack deployable from a single `docker compose up -d`
- README: home lab network guide — direct hosting, port forwarding, DMZ, and dynamic DNS options for exposing port 80
- README: all steps written in do / what you'll see / why it matters format
- Validated on Intel x86 + NVIDIA GTX1650 4 GB and NVIDIA Jetson Orin Nano 8 GB shared memory
