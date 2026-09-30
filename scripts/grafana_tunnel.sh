#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [LOCAL_PORT]

Opens an SSM port forwarding session to the Grafana task on the watchfloor cluster.

Arguments:
    LOCAL_PORT  Optional. Local port to forward to Grafana. Default is 3001.

Examples:
  $(basename "$0")        # http://localhost:3001
  $(basename "$0") 1211   # http://localhost:1211
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v aws >/dev/null; then
  echo "AWS CLI not installed" >&2
  exit 1
fi

PORT="${1:-3001}"
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || ((PORT < 1 || PORT > 65535 )); then
  echo "Invalid port: '$PORT' (must be 1-65535)" >&2
  usage >&2
  exit 1
fi

if [[ -z "${1:-}" ]]; then
    echo "No port given, using default ${PORT}. Run with --help or -h for usage help."
fi

TASK="$(aws ecs list-tasks --cluster watchfloor-cluster \
--service-name watchfloor-obs-grafana-service --query 'taskArns[0]' --output text | awk -F/ '{print $NF}')"

if [ "$TASK" == "None" ]; then
  echo "No Grafana task is currently running. Run Terraform Apply workflow." >&2
  exit 1
fi

RUNTIME=$(aws ecs describe-tasks --cluster watchfloor-cluster --tasks "$TASK" \
--query 'tasks[0].containers[0].runtimeId' --output text)

if ! command -v clip.exe >/dev/null; then
  echo "clip.exe not found, skipping password copy to clipboard"
elif ! PASS="$(aws ssm get-parameter --name /watchfloor/GF_SECURITY_ADMIN_PASSWORD \
--with-decryption --query Parameter.Value --output text 2>/dev/null)"; then
    echo "Could not read Grafana password from SSM (is the stack applied?)" >&2
else
  printf '%s' "$PASS" | clip.exe
  echo "Grafana admin password copied to clipboard (username: admin)"
fi

echo "Forwarding localhost:${PORT} -> Grafana:3000 (ctrl+c to stop) Link: http://localhost:$PORT"

aws ssm start-session --target "ecs:watchfloor-cluster_${TASK}_${RUNTIME}" \
--document-name AWS-StartPortForwardingSession \
--parameters "portNumber=3000,localPortNumber=${PORT}"
