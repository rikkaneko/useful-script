#!/bin/bash
# 
# Simple Cloudflare DDNS Client
# Prerequisite
# curl, jq, dig
#
# .env
# CLOUDFLARE_API_KEY=<Cloudflare API Key, requires DNS Write permission>
# CLOUDFLARE_ZONE_ID=<Zone ID, Find this ID in Overview page of your domain>
# DOMAINS=("subdomain1.example.com" "subdomain2.example.com" "subdomainN.example.com")
#

ENV_FILE=".env"

if [[ "$1" == "--env-file" && ! -z "$2" ]]; then
  ENV_FILE="$2"
fi

require_cmds=("curl" "jq" "dig")

for cmd in "${require_cmds[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Cannot find '$cmd' command in the system."
      exit 1
    fi
done

source $ENV_FILE

for DOMAIN in "${DOMAINS[@]}"; do
  echo -e "*** Processing $DOMAIN ***"
  OLD_DNS_IP=$(dig +short ${DOMAIN} A @1.1.1.1)
  echo "Current IPv4 record for ${DOMAIN}: ${OLD_DNS_IP}"

  NEW_DNS_IP="$(curl -s https://cloudflare.com/cdn-cgi/trace | grep "^ip=" | cut -d'=' -f2-)"
  echo "Public IP: ${NEW_DNS_IP}"
  if [[ "${OLD_DNS_IP}" == "${NEW_DNS_IP}" ]]; then
    echo "${DOMAIN} has already pointed to ${NEW_DNS_IP}. No need to update."
    continue
  fi

  JSON_RES=$(
    curl -s https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name.exact=${DOMAIN} \
      -H "Authorization: Bearer ${CLOUDFLARE_API_KEY}"
  )

  DNS_RECORD_ID=""

  if echo "$JSON_RES" | jq -e '.result | length > 0' >/dev/null; then
    DNS_RECORD_ID=$(echo "$JSON_RES" | jq -r '.result[0].id')
    echo "DNS Record ID: ${DNS_RECORD_ID} (${DOMAIN})"
  else
    echo "Domain name \"${DOMAIN}\" does not exist in this zone."
    continue
  fi

  echo "Updating the DNS IPv4 record for ${DOMAIN} to ${NEW_DNS_IP} ..."
  JSON_RES=$(
    curl -s https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${DNS_RECORD_ID} \
      -X PATCH \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer ${CLOUDFLARE_API_KEY}" \
      -d "{ \
            \"name\": \"${DOMAIN}\", \
            \"ttl\": 1, \
            \"type\": \"A\", \
            \"content\": \"${NEW_DNS_IP}\" \
          }"
  )

  if [[ $(echo "$JSON_RES" | jq -e '.success') == "true" ]]; then
    echo "DNS update success."
  else
    echo "DNS update fail."
    echo "${$JSON_RES}"
    continue
  fi

  echo "Wait 30s for DNS DNS propagation ..."
  sleep 30
  DNS_IP=$(dig +short ${DOMAIN} A @1.1.1.1)
  echo "Current IPv4 record for ${DOMAIN}: ${DNS_IP} (Old: ${OLD_DNS_IP})"
done
