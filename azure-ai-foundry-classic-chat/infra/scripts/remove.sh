#!/usr/bin/env bash
# Granular delete for classic Foundry infra (day-2 ops).
#
# Usage:
#   ./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-project --env dev
#   ./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-hub --env dev
#   ./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-account --env dev
#   ./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove --env dev          # entire RG
#   ./azure-ai-foundry-classic-chat/infra/scripts/remove.sh delete --env prod         # alias

set -euo pipefail

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
common_init

ACTION="${1:-help}"
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENVIRONMENT="$2"; RG_NAME="rg-${WORKLOAD}-${ENVIRONMENT}-${REGION_SHORT}"; shift 2 ;;
    -h|--help) ACTION=help; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

usage() {
  cat <<EOF
Remove classic Foundry resources (granular or full RG)

Usage:
  ./azure-ai-foundry-classic-chat/infra/scripts/remove.sh <command> [--env dev|test|prod]

Commands:
  remove-project    Delete hub project only
  remove-hub        Delete classic hub (delete project first if needed)
  remove-account    Delete AI Services account (and model deployments)
  remove            Delete entire resource group (alias: delete, destroy)
  help              Show this help

Config: .env.{environment} (from deploy.sh)

Examples:
  ./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-project --env dev
  ./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove --env dev
EOF
}

cmd_remove_project() {
  load_env_file
  confirm_prod_action "delete hub project ${PROJECT_NAME}"
  if ! az ml workspace show -g "${RESOURCE_GROUP_NAME}" -n "${PROJECT_NAME}" --output none 2>/dev/null; then
    echo "Project '${PROJECT_NAME}' not found — nothing to remove."
    return 0
  fi
  confirm_yes "Delete hub project '${PROJECT_NAME}'?"
  az ml workspace delete -g "${RESOURCE_GROUP_NAME}" -n "${PROJECT_NAME}" --yes --no-wait
  echo "Delete started for project '${PROJECT_NAME}'."
}

cmd_remove_hub() {
  load_env_file
  confirm_prod_action "delete hub ${HUB_NAME}"
  if ! az ml workspace show -g "${RESOURCE_GROUP_NAME}" -n "${HUB_NAME}" --output none 2>/dev/null; then
    echo "Hub '${HUB_NAME}' not found — nothing to remove."
    return 0
  fi
  confirm_yes "Delete classic hub '${HUB_NAME}'? (remove project first if delete fails)"
  az ml workspace delete -g "${RESOURCE_GROUP_NAME}" -n "${HUB_NAME}" --yes --no-wait
  echo "Delete started for hub '${HUB_NAME}'."
}

cmd_remove_account() {
  load_env_file
  confirm_prod_action "delete AI Services account ${COG_SERVICES_ACCOUNT_NAME}"
  if ! az cognitiveservices account show -g "${RESOURCE_GROUP_NAME}" -n "${COG_SERVICES_ACCOUNT_NAME}" --output none 2>/dev/null; then
    echo "Account '${COG_SERVICES_ACCOUNT_NAME}' not found — nothing to remove."
    return 0
  fi
  confirm_yes "Delete AI Services account '${COG_SERVICES_ACCOUNT_NAME}' (and its deployments)?"
  az cognitiveservices account delete -g "${RESOURCE_GROUP_NAME}" -n "${COG_SERVICES_ACCOUNT_NAME}" --yes
  echo "Deleted account '${COG_SERVICES_ACCOUNT_NAME}'."
}

cmd_remove_rg() {
  validate_environment
  confirm_prod_action "delete resource group ${RG_NAME}"

  if [[ "${ENVIRONMENT}" == "prod" ]]; then
    echo "Type RG name to confirm deletion: ${RG_NAME}"
    read -r -p "> " reply
    if [[ "${reply}" != "${RG_NAME}" ]]; then
      echo "Cancelled."
      exit 0
    fi
  else
    confirm_yes "DELETE resource group '${RG_NAME}' and ALL resources inside it?"
  fi

  if ! az group exists --name "${RG_NAME}" | grep -qi true; then
    echo "Resource group '${RG_NAME}' not found — nothing to remove."
    return 0
  fi

  az group delete --name "${RG_NAME}" --yes --no-wait
  echo "Delete started for '${RG_NAME}'."

  local env_file
  env_file="$(env_file_path)"
  if [[ -f "${env_file}" ]]; then
    read -r -p "Remove local ${env_file}? [y/N] " reply
    case "${reply}" in
      y|Y|yes|YES) rm -f "${env_file}"; echo "Removed ${env_file}" ;;
    esac
  fi
}

ensure_ml_extension() {
  if az ml workspace -h >/dev/null 2>&1; then
    return 0
  fi
  echo "Installing Azure ML CLI extension (needed for hub/project delete)..."
  az extension add -n ml --upgrade --yes --only-show-errors 2>/dev/null \
    || az extension add -n ml --yes --only-show-errors
}

main() {
  case "${ACTION}" in
    remove-project|delete-project)
      require_login
      ensure_ml_extension
      cmd_remove_project
      ;;
    remove-hub|delete-hub)
      require_login
      ensure_ml_extension
      cmd_remove_hub
      ;;
    remove-account|delete-account)
      require_login
      cmd_remove_account
      ;;
    remove|delete|destroy)
      require_login
      cmd_remove_rg
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      echo "Unknown command: ${ACTION}"
      usage
      exit 1
      ;;
  esac
}

main
