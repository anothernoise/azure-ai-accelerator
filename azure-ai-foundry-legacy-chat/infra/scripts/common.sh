#!/usr/bin/env bash
# Shared helpers for azure-ai-foundry-legacy-chat/infra/scripts (source, do not execute directly).

PROVIDER_MAX_ATTEMPTS="${PROVIDER_MAX_ATTEMPTS:-60}"
PROVIDER_POLL_SECONDS="${PROVIDER_POLL_SECONDS:-5}"

common_init() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  fi
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
  BICEP_DIR="${REPO_ROOT}/azure-ai-foundry-legacy-chat/infra/bicep"

  ENVIRONMENT="${ENVIRONMENT:-dev}"
  WORKLOAD="${WORKLOAD:-aialearn}"
  REGION_SHORT="${REGION_SHORT:-eus}"
  RG_NAME="${RG_NAME:-rg-${WORKLOAD}-${ENVIRONMENT}-${REGION_SHORT}}"
}

parse_env_flag() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)
        ENVIRONMENT="${2:?missing value for --env}"
        RG_NAME="rg-${WORKLOAD}-${ENVIRONMENT}-${REGION_SHORT}"
        shift 2
        ;;
      *) break ;;
    esac
  done
  REPLY_ARGS=("$@")
}

validate_environment() {
  case "${ENVIRONMENT}" in
    dev|test|prod) ;;
    *)
      echo "Invalid ENVIRONMENT='${ENVIRONMENT}'. Use dev, test, or prod."
      exit 1
      ;;
  esac
}

require_login() {
  if ! az account show --output none 2>/dev/null; then
    echo "Not logged in. Run: az login && az account set --subscription \"<id>\""
    exit 1
  fi
}

confirm_yes() {
  local prompt="$1"
  read -r -p "${prompt} [y/N] " reply
  case "${reply}" in
    y|Y|yes|YES) return 0 ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
}

confirm_prod_action() {
  local action="$1"
  if [[ "${ENVIRONMENT}" != "prod" ]]; then
    return 0
  fi
  echo "WARNING: PRODUCTION action — ${action}"
  echo "  Environment: ${ENVIRONMENT}"
  echo "  RG: ${RG_NAME}"
  read -r -p "Continue? [y/N] " reply
  case "${reply}" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
}

env_file_path() {
  echo "${REPO_ROOT}/.env.${ENVIRONMENT}"
}

# RG for Bicep stack: CAF default, or .env.{env} when ENVIRONMENT_NAME matches.
# Ignores legacy repo-root .env when .env.{env} is missing (avoids my-foundry-rg drift).
resolve_resource_group() {
  local env_file computed
  env_file="$(env_file_path)"
  computed="rg-${WORKLOAD}-${ENVIRONMENT}-${REGION_SHORT}"

  if [[ -n "${RG_NAME:-}" && "${RG_NAME}" != "${computed}" ]]; then
    # Caller set RG_NAME explicitly (e.g. RG_NAME=my-rg ./script.sh)
    return 0
  fi

  if [[ -f "${env_file}" ]]; then
    local saved_environment="${ENVIRONMENT_NAME:-}"
    local saved_rg="${RESOURCE_GROUP_NAME:-}"
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
    if [[ "${ENVIRONMENT_NAME:-}" == "${ENVIRONMENT}" && -n "${RESOURCE_GROUP_NAME:-}" ]]; then
      RG_NAME="${RESOURCE_GROUP_NAME}"
      return 0
    fi
    ENVIRONMENT_NAME="${saved_environment}"
    RESOURCE_GROUP_NAME="${saved_rg}"
  fi

  RG_NAME="${computed}"
  if [[ -f "${REPO_ROOT}/.env" && ! -f "${env_file}" ]]; then
    echo "Note: .env.${ENVIRONMENT} not found — using Bicep RG '${RG_NAME}' (ignoring legacy .env)"
  fi
}

load_env_file() {
  local env_file
  env_file="$(env_file_path)"
  if [[ ! -f "${env_file}" ]]; then
    env_file="${REPO_ROOT}/.env"
  fi
  if [[ ! -f "${env_file}" ]]; then
    echo "Missing ${env_file}. Deploy first:"
    echo "  ENVIRONMENT=${ENVIRONMENT} ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh"
    echo "  (from repo root, or: cd azure-ai-foundry-legacy-chat/infra/scripts && ./deploy.sh --env ${ENVIRONMENT})"
    exit 1
  fi
  if [[ "${env_file}" == "${REPO_ROOT}/.env" && ! -f "$(env_file_path)" ]]; then
    echo "Warning: using legacy ${env_file} — deploy Bicep to create .env.${ENVIRONMENT}"
  fi
  set -a
  # shellcheck disable=SC1090
  source "${env_file}"
  set +a
  ENV_FILE="${env_file}"
}

register_providers() {
  local ns state attempt
  for ns in \
    Microsoft.CognitiveServices \
    Microsoft.MachineLearningServices \
    Microsoft.Storage \
    Microsoft.KeyVault \
    Microsoft.Insights \
    Microsoft.OperationalInsights; do
    state="$(az provider show -n "${ns}" --query registrationState -o tsv 2>/dev/null || echo Unknown)"
    if [[ "${state}" == "Registered" ]]; then
      continue
    fi
    echo "Registering ${ns} (current: ${state})..."
    az provider register -n "${ns}" --output none
    attempt=0
    while true; do
      state="$(az provider show -n "${ns}" --query registrationState -o tsv 2>/dev/null || echo Unknown)"
      if [[ "${state}" == "Registered" ]]; then
        echo "Provider ${ns}: Registered"
        break
      fi
      attempt=$((attempt + 1))
      if [[ "${attempt}" -ge "${PROVIDER_MAX_ATTEMPTS}" ]]; then
        echo "Timed out waiting for ${ns} (last state: ${state})."
        exit 1
      fi
      echo "  waiting for ${ns}... (${state}) [${attempt}/${PROVIDER_MAX_ATTEMPTS}]"
      sleep "${PROVIDER_POLL_SECONDS}"
    done
  done
}

latest_arm_deployment() {
  local rg="$1"
  local prefix="$2"
  az deployment group list \
    -g "${rg}" \
    --query "reverse(sort_by([?starts_with(name, '${prefix}') && properties.provisioningState=='Succeeded'], &properties.timestamp))[0].name" \
    -o tsv 2>/dev/null || true
}
