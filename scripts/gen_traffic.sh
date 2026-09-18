#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/.env.traffic"

: "${WF_PASSWORD:?WF_PASSWORD not set in scripts/.env.traffic}"
: "${WF_EMAIL:?WF_EMAIL not set in scripts/.env.traffic}"
API="${API:-http://localhost:8000}"
COUNT="${COUNT:-20}"

devices=(core-sw-01 edge-fw-02 nas-backup-01 dist-sw-01 dns-srv-02)
errors=(interface_down disk_usage_high tunnel_flap packet_loss_high service_down)

JAR="$(mktemp)"

trap 'rm -f "$JAR"' EXIT

body="$(jq -n --arg email "$WF_EMAIL" --arg password "$WF_PASSWORD" '{email: $email, password: $password}')"

register_code="$(curl -s -o /dev/null -w  "%{http_code}" -H "Content-Type: application/json" -d "$body" "$API/auth/register")"

if [[ "$register_code" != "201" && "$register_code" != "409" ]]; then
  echo 'Unable to create user' >&2
  exit 1
fi

login_code="$(curl -c "$JAR" -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$body" "$API/auth/login")"
if [[ "$login_code" != "200" ]]; then
  echo 'Unable to login' >&2
  exit 1
fi

for ((i = 1; i<= COUNT; i++)); do
  devicetemp="${devices[RANDOM % ${#devices[@]}]}"
  errortemp="${errors[RANDOM % ${#errors[@]}]}"
  bodytemp=
done
