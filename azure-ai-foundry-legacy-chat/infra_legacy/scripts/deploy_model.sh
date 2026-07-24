#!/bin/bash
# deploy_model.sh — manage Azure OpenAI model deployments on existing infra
#
# Prerequisites: ./deploy_infra.sh create (same ../.env values)
#
# Usage:
#   ./deploy_model.sh create       # deploy MODEL_NAME as DEPLOYMENT_NAME
#   ./deploy_model.sh list         # list deployments
#   ./deploy_model.sh show         # show DEPLOYMENT_NAME
#   ./deploy_model.sh update       # update capacity / sku
#   ./deploy_model.sh remove       # delete DEPLOYMENT_NAME
#   ./deploy_model.sh remove-all   # delete all deployments on the account
#   ./deploy_model.sh help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=azure.config.sh
source "${SCRIPT_DIR}/azure.config.sh"

ACTION="${1:-help}"

require_login() {
  if ! az account show --output none 2>/dev/null; then
    echo "Not logged in. Run: az login && az account set --subscription \"<id>\""
    exit 1
  fi
}

ensure_cli() {
  # az cognitiveservices is built into modern Azure CLI (no extension required).
  if ! az cognitiveservices account deployment -h >/dev/null 2>&1; then
    echo "Azure CLI is missing 'az cognitiveservices account deployment'. Upgrade CLI."
    exit 1
  fi
}

require_account() {
  if ! az cognitiveservices account show \
      --name "${COG_SERVICES_ACCOUNT_NAME}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --output none 2>/dev/null; then
    echo "OpenAI account '${COG_SERVICES_ACCOUNT_NAME}' not found in RG '${RESOURCE_GROUP_NAME}'."
    echo "Run ./deploy_infra.sh create first, or fix ../.env."
    exit 1
  fi
}

confirm() {
  local prompt="$1"
  read -r -p "${prompt} [y/N] " reply
  case "${reply}" in
    y|Y|yes|YES) return 0 ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
}

cmd_create() {
  echo "--- Creating deployment: ${DEPLOYMENT_NAME} ---"
  echo "    model=${MODEL_NAME} version=${MODEL_VERSION}"
  echo "    sku=${DEPLOYMENT_SKU_NAME} capacity=${DEPLOYMENT_SKU_CAPACITY}"

  az cognitiveservices account deployment create \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --deployment-name "${DEPLOYMENT_NAME}" \
    --model-name "${MODEL_NAME}" \
    --model-version "${MODEL_VERSION}" \
    --model-format "${MODEL_FORMAT}" \
    --sku-name "${DEPLOYMENT_SKU_NAME}" \
    --sku-capacity "${DEPLOYMENT_SKU_CAPACITY}" \
    --output table

  echo
  echo "Done. Use deployment name '${DEPLOYMENT_NAME}' as model= in chat.py"
  echo "Remove later: ./deploy_model.sh remove"
}

cmd_list() {
  echo "--- Deployments on ${COG_SERVICES_ACCOUNT_NAME} ---"
  az cognitiveservices account deployment list \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --output table
}

cmd_show() {
  echo "--- Deployment: ${DEPLOYMENT_NAME} ---"
  az cognitiveservices account deployment show \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --deployment-name "${DEPLOYMENT_NAME}" \
    --output table
}

cmd_update() {
  echo "--- Updating deployment: ${DEPLOYMENT_NAME} ---"
  echo "    sku=${DEPLOYMENT_SKU_NAME} capacity=${DEPLOYMENT_SKU_CAPACITY}"

  az cognitiveservices account deployment update \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --deployment-name "${DEPLOYMENT_NAME}" \
    --sku-name "${DEPLOYMENT_SKU_NAME}" \
    --sku-capacity "${DEPLOYMENT_SKU_CAPACITY}" \
    --output table
}

cmd_remove() {
  echo "--- Removing deployment: ${DEPLOYMENT_NAME} ---"

  if ! az cognitiveservices account deployment show \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --name "${COG_SERVICES_ACCOUNT_NAME}" \
      --deployment-name "${DEPLOYMENT_NAME}" \
      --output none 2>/dev/null; then
    echo "Deployment '${DEPLOYMENT_NAME}' not found — nothing to remove."
    return 0
  fi

  confirm "Delete model deployment '${DEPLOYMENT_NAME}'?"

  az cognitiveservices account deployment delete \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --deployment-name "${DEPLOYMENT_NAME}" \
    --yes

  echo "Deleted '${DEPLOYMENT_NAME}'."
}

cmd_remove_all() {
  echo "--- Removing ALL deployments on ${COG_SERVICES_ACCOUNT_NAME} ---"

  mapfile -t names < <(
    az cognitiveservices account deployment list \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --name "${COG_SERVICES_ACCOUNT_NAME}" \
      --query "[].name" -o tsv 2>/dev/null || true
  )

  if [[ ${#names[@]} -eq 0 || -z "${names[0]:-}" ]]; then
    echo "No deployments found."
    return 0
  fi

  echo "Will delete:"
  printf '  - %s\n' "${names[@]}"
  confirm "Delete ALL ${#names[@]} deployment(s)?"

  for name in "${names[@]}"; do
    [[ -z "${name}" ]] && continue
    echo "Deleting '${name}'..."
    az cognitiveservices account deployment delete \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --name "${COG_SERVICES_ACCOUNT_NAME}" \
      --deployment-name "${name}" \
      --yes
  done

  echo "All deployments deleted."
}

cmd_help() {
  cat <<EOF
Manage AI model deployments (Lesson 1)

Usage: ./deploy_model.sh <command>

Commands:
  create       Create deployment from ../.env settings
  list         List all deployments on the OpenAI account
  show         Show DEPLOYMENT_NAME details
  update       Update sku/capacity for DEPLOYMENT_NAME
  remove       Delete DEPLOYMENT_NAME (alias: delete)
  remove-all   Delete all deployments on the account
  help         Show this help

Shared config: ../.env (via azure.config.sh)
Infra:         ./deploy_infra.sh create | remove-account | remove
EOF
}

main() {
  case "${ACTION}" in
    create|list|show|update)
      require_login
      ensure_cli
      require_account
      "cmd_${ACTION}"
      ;;
    remove|delete)
      require_login
      ensure_cli
      require_account
      cmd_remove
      ;;
    remove-all|delete-all)
      require_login
      ensure_cli
      require_account
      cmd_remove_all
      ;;
    help|-h|--help)
      cmd_help
      ;;
    *)
      echo "Unknown command: ${ACTION}"
      cmd_help
      exit 1
      ;;
  esac
}

main "$@"
