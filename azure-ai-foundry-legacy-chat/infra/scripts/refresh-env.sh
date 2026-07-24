#!/usr/bin/env bash
# Refresh .env.{environment} from an existing ARM deployment (no redeploy).
#
# Usage:
#   ./azure-ai-foundry-legacy-chat/infra/scripts/refresh-env.sh --env dev
#   ./azure-ai-foundry-legacy-chat/infra/scripts/refresh-env.sh --env dev --deployment aialearn-dev-20250723120000
#   ./azure-ai-foundry-legacy-chat/infra/scripts/refresh-env.sh --env dev --live-connection

set -euo pipefail

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
common_init

ARM_DEPLOYMENT=""
LIVE_CONNECTION=0
COPY_ACTIVE=1

usage() {
  cat <<EOF
Refresh local env file from Azure (day-2 ops)

Usage:
  ./refresh-env.sh [--env dev|test|prod] [options]

  From repo root:
  ./azure-ai-foundry-legacy-chat/infra/scripts/refresh-env.sh --env dev

Options:
  --deployment NAME   ARM deployment name (default: latest succeeded aialearn-\$ENVIRONMENT-*)
  --live-connection   Rebuild AZURE_PROJECT_CONNECTION_STRING from live project discovery_url
  --no-copy-active    Do not copy .env.\$ENVIRONMENT → .env

Examples:
  ./azure-ai-foundry-legacy-chat/infra/scripts/refresh-env.sh --env dev
  ./azure-ai-foundry-legacy-chat/infra/scripts/refresh-env.sh --env dev --live-connection
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENVIRONMENT="$2"; RG_NAME="rg-${WORKLOAD}-${ENVIRONMENT}-${REGION_SHORT}"; shift 2 ;;
    --deployment) ARM_DEPLOYMENT="$2"; shift 2 ;;
    --live-connection) LIVE_CONNECTION=1; shift ;;
    --no-copy-active) COPY_ACTIVE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

validate_environment
require_login
resolve_resource_group

if [[ -z "${ARM_DEPLOYMENT}" ]]; then
  ARM_DEPLOYMENT="$(latest_arm_deployment "${RG_NAME}" "aialearn-${ENVIRONMENT}-")"
fi

if [[ -z "${ARM_DEPLOYMENT}" || "${ARM_DEPLOYMENT}" == "null" ]]; then
  echo "No succeeded ARM deployment found in RG '${RG_NAME}' matching aialearn-${ENVIRONMENT}-*"
  echo ""
  echo "Bicep has not been deployed for this environment yet. From repo root:"
  echo "  ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh --env ${ENVIRONMENT}"
  echo "Or from this directory:"
  echo "  ./deploy.sh --env ${ENVIRONMENT}"
  exit 1
fi

env_file="$(env_file_path)"
echo "Refreshing ${env_file}"
echo "  RG: ${RG_NAME}"
echo "  ARM deployment: ${ARM_DEPLOYMENT}"

write_args=(
  --resource-group "${RG_NAME}"
  --deployment "${ARM_DEPLOYMENT}"
  --environment "${ENVIRONMENT}"
  --env-file "${env_file}"
)
if [[ "${LIVE_CONNECTION}" -eq 1 ]]; then
  write_args+=(--live-connection)
fi

python3 "${SCRIPT_DIR}/write_env.py" "${write_args[@]}"

if [[ "${COPY_ACTIVE}" -eq 1 ]]; then
  cp "${env_file}" "${REPO_ROOT}/.env"
  echo "Updated active local config: ${REPO_ROOT}/.env"
fi
