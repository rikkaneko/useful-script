#!/bin/bash
set -a
source .env
set +a

for DOMAIN in "${DOMAINS[@]}"; do
  acme.sh --cert-home "${CERT_HOME:-${HOME}/.acme.sh}" --issue --dns dns_cf -d "${DOMAIN}"
  mkdir -p "${DOMAIN}"
  acme.sh --cert-home "${CERT_HOME:-${HOME}/.acme.sh}" --install-cert -d "${DOMAIN}" --fullchain-file "${DOMAIN}/fullchain.pem" --key-file "${DOMAIN}/privkey.pem"
  chmod g+r "${DOMAIN}/privkey.pem"
done