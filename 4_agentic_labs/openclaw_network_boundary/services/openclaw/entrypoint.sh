#!/usr/bin/env bash
# Copyright (c) 2026 markosluga
# SPDX-License-Identifier: Apache-2.0
#
# 0. Apply iptables OUTPUT rules — block direct internet; allow only RFC1918 (Docker-internal) destinations
# 1. Render openclaw.json from template using env vars
# 2. Wait for ollama to become ready
# 3. Start the OpenClaw gateway

set -euo pipefail

OLLAMA_URL="http://ollama:11434/api/tags"
CONFIG_DIR="/root/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
TEMPLATE="/etc/openclaw/openclaw.json.template"

log() { echo "[openclaw-entrypoint] $*"; }

# ── Step 0: Block direct internet access ────────────────────────────────────
# Use iptables-legacy (xtables) — the Jetson 5.15 kernel supports xtables but
# not nf_tables, so iptables-nft (Debian default) fails with RULE_APPEND errors.
# Allow only RFC1918 destinations (all Docker internal networks). All public-IP
# traffic must flow through the nginx forward proxy. If NET_ADMIN is missing,
# warn and continue.
log "Applying iptables network isolation (iptables-legacy)..."
if iptables-legacy -F OUTPUT 2>/dev/null; then
  iptables-legacy -A OUTPUT -o lo             -j ACCEPT
  iptables-legacy -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables-legacy -A OUTPUT -d 10.0.0.0/8    -j ACCEPT
  iptables-legacy -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
  iptables-legacy -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
  iptables-legacy -P OUTPUT DROP
  log "iptables OUTPUT policy set: RFC1918 allowed, public internet blocked."
else
  log "WARNING: iptables-legacy unavailable — network isolation NOT enforced. Ensure cap_add: NET_ADMIN is set."
fi

# ── Step 1: Render config from template ─────────────────────────────────────
mkdir -p "${CONFIG_DIR}"
log "Rendering openclaw.json (model=${OLLAMA_MODEL}, port=19000)..."
envsubst < "${TEMPLATE}" > "${CONFIG_FILE}"
log "Config written to ${CONFIG_FILE}."

# ── Step 2: Wait for ollama ──────────────────────────────────────────────────
log "Waiting for ollama at ${OLLAMA_URL}..."
until curl -sf "${OLLAMA_URL}" > /dev/null 2>&1; do
  sleep 3
done
log "Ollama is reachable."

# ── Step 3: Start gateway ────────────────────────────────────────────────────
log "Starting OpenClaw gateway on port 19000..."
exec openclaw gateway run
