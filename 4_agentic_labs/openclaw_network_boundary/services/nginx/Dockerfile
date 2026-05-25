# Copyright (c) 2026 markosluga
# SPDX-License-Identifier: Apache-2.0
#
# nginx:1.31.1-otel ships with ngx_otel_module and ngx_http_acme_module.
# HTTPS CONNECT tunneling (ngx_http_proxy_connect_module) requires a source
# patch that does not yet apply cleanly to 1.31.x — tracked for a future release.
# HTTP forward proxy (port 8080) works natively; HTTPS uses kernel iptables isolation.

FROM nginx:1.31.1-otel

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
