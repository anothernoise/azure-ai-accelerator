#!/usr/bin/env bash
# Deploy Lesson 1 classic Foundry infra from Bicep (dev / prod environments).
#
# Usage (from repo root):
#   ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh
#   ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh --env dev --what-if
#   ENVIRONMENT=prod ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh
#
# Writes: .env.{ENVIRONMENT} and updates .env (active pointer for local runs)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BICEP_DIR="${REPO_ROOT}/azure-ai-foundry-legacy-chat/infra/bicep"

ENVIRONMENT="${ENVIRONMENT:-dev}"
WORKLOAD="${WORKLOAD:-aialearn}"
REGION_SHORT="${REGION_SHORT:-eus}"
LOCATION="${LOCATION:-eastus}"
WHAT_IF=0

usage() {
  cat <<EOF
Deploy classic Foundry hub infra (Bicep)

Usage:
  ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh [--env dev|prod|test] [--what-if]

Environment variables:
  ENVIRONMENT    dev (default) | prod | test
  WORKLOAD       workload slug in CAF names (default: aialearn)
  REGION_SHORT   region code in names (default: eus)
  LOCATION       Azure region (default: eastus)
  RG_NAME        override resource group (default: rg-\$WORKLOAD-\$ENVIRONMENT-\$REGION_SHORT)
  ARM_DEPLOYMENT_NAME  ARM deployment name (default: aialearn-\$ENVIRONMENT-YYYYMMDDHHMMSS)

Outputs:
  \${REPO_ROOT}/.env.\${ENVIRONMENT}  — environment-specific config
  \${REPO_ROOT}/.env                — copy of active environment (local default)

Examples:
  ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh --env dev --what-if
  ENVIRONMENT=prod ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)
        ENVIRONMENT="${2:?missing value for --env}"
        shift 2
        ;;
      --what-if) WHAT_IF=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown argument: $1"; usage; exit 1 ;;
    esac
  done

  case "${ENVIRONMENT}" in
    dev|prod|test) ;;
    *)
      echo "Invalid ENVIRONMENT='${ENVIRONMENT}'. Use dev, prod, or test."
      exit 1
      ;;
  esac
}

require_login() {
  if ! az account show --output none 2>/dev/null; then
    echo "Not logged in. Run: az login && az account set --subscription \"<id>\""
    exit 1
  fi
  echo "Logged in as:"
  az account show --query "{user:user.name, subscription:name, id:id}" -o table
}

confirm_prod() {
  if [[ "${ENVIRONMENT}" != "prod" || "${WHAT_IF}" -eq 1 ]]; then
    return 0
  fi
  echo "WARNING: PRODUCTION deploy (ENVIRONMENT=prod)"
  echo "  RG: ${RG_NAME}"
  echo "  Subscription: $(az account show --query name -o tsv)"
  read -r -p "Continue? [y/N] " reply
  case "${reply}" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
}

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

create_rg() {
  echo "--- Resource group: ${RG_NAME} (${LOCATION}) [env=${ENVIRONMENT}] ---"
  az group create \
    --name "${RG_NAME}" \
    --location "${LOCATION}" \
    --tags "env=${ENVIRONMENT}" "workload=${WORKLOAD}" "managedBy=bicep" \
    -o table
}

deploy() {
  local param_file="${BICEP_DIR}/environments/${ENVIRONMENT}.bicepparam"
  if [[ ! -f "${param_file}" ]]; then
    echo "Missing parameter file: ${param_file}"
    exit 1
  fi

  if [[ "${WHAT_IF}" -eq 1 ]]; then
    echo "--- What-if (${ENVIRONMENT}) ---"
    az deployment group what-if \
      --name "${ARM_DEPLOYMENT_NAME}" \
      --resource-group "${RG_NAME}" \
      --template-file "${BICEP_DIR}/main.bicep" \
      --parameters "${param_file}" \
      --parameters "location=${LOCATION}" \
      --result-format FullResourcePayloads
    return 0
  fi

  echo "--- Deploying Bicep (${ENVIRONMENT} / ${ARM_DEPLOYMENT_NAME}) ---"
  az deployment group create \
    --name "${DEPLOYMENT_NAME}" \
    --resource-group "${RG_NAME}" \
    --template-file "${BICEP_DIR}/main.bicep" \
    --parameters "${param_file}" \
    --parameters "location=${LOCATION}" \
    -o table

  local env_file="${REPO_ROOT}/.env.${ENVIRONMENT}"
  echo "--- Writing ${env_file} ---"
  python3 "${SCRIPT_DIR}/write_env.py" \
    --resource-group "${RG_NAME}" \
    --deployment "${ARM_DEPLOYMENT_NAME}" \
    --environment "${ENVIRONMENT}" \
    --env-file "${env_file}"

  cp "${env_file}" "${REPO_ROOT}/.env"
  echo "Active local config: ${REPO_ROOT}/.env (copy of .env.${ENVIRONMENT})"
}

main() {
  parse_args "$@"

  PARAM_FILE="${BICEP_DIR}/environments/${ENVIRONMENT}.bicepparam"
  RG_NAME="${RG_NAME:-rg-${WORKLOAD}-${ENVIRONMENT}-${REGION_SHORT}}"
  ARM_DEPLOYMENT_NAME="${ARM_DEPLOYMENT_NAME:-aialearn-${ENVIRONMENT}-$(date +%Y%m%d%H%M%S)}"
  ENV_FILE="${REPO_ROOT}/.env.${ENVIRONMENT}"

  echo "Environment : ${ENVIRONMENT}"
  echo "Param file  : ${PARAM_FILE}"
  echo "Env file    : ${ENV_FILE}"

  require_login
  confirm_prod
  register_providers
  create_rg
  deploy

  if [[ "${WHAT_IF}" -eq 0 ]]; then
    echo
    echo "Done. Run chat:"
    echo "  cd azure-ai-foundry-legacy-chat && ENVIRONMENT=${ENVIRONMENT} ../.venv/bin/python chat.py"
  fi
}

main "$@"
