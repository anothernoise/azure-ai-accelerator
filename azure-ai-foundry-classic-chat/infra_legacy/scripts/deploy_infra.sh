#!/bin/bash
# deploy_infra.sh — classic Foundry hub infra for Lesson 1
#
# Creates:
#   resource group + Azure OpenAI account + classic AI Hub + hub project
# Also writes AZURE_PROJECT_CONNECTION_STRING into ../.env
#
# Usage:
#   ./deploy_infra.sh create              # full stack (default)
#   ./deploy_infra.sh connection-string   # print + write connection string to .env
#   ./deploy_infra.sh remove-project      # delete hub project only
#   ./deploy_infra.sh remove-hub          # delete hub (projects must be gone)
#   ./deploy_infra.sh remove-account      # delete OpenAI account only
#   ./deploy_infra.sh remove              # delete entire resource group
#   ./deploy_infra.sh help
#
# Config: ../.env (via azure.config.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
# shellcheck source=azure.config.sh
source "${SCRIPT_DIR}/azure.config.sh"

ACTION="${1:-create}"

require_login() {
  if ! az account show --output none 2>/dev/null; then
    echo "Not logged in (or no subscription selected)."
    echo "Run: az login && az account set --subscription \"<subscription-id>\""
    exit 1
  fi
  echo "Logged in as:"
  az account show --query "{user:user.name, subscription:name, id:id}" --output table
}

ensure_cli() {
  if ! az cognitiveservices account -h >/dev/null 2>&1; then
    echo "Azure CLI is missing 'az cognitiveservices'. Upgrade Azure CLI."
    exit 1
  fi

  echo "--- Ensuring Azure ML CLI extension (for classic hub/project) ---"
  az extension add -n ml --upgrade --yes --only-show-errors 2>/dev/null \
    || az extension add -n ml --yes --only-show-errors

  if ! az ml workspace -h >/dev/null 2>&1; then
    echo "Failed to install 'ml' extension. Try: az extension add -n ml"
    exit 1
  fi
}

register_providers() {
  local providers=(
    "Microsoft.CognitiveServices"
    "Microsoft.MachineLearningServices"
    "Microsoft.Storage"
    "Microsoft.KeyVault"
    "Microsoft.Insights"
  )
  local ns state attempt
  local max_attempts=60

  for ns in "${providers[@]}"; do
    state="$(az provider show --namespace "${ns}" --query registrationState -o tsv 2>/dev/null || echo "Unknown")"
    if [[ "${state}" == "Registered" ]]; then
      echo "Provider ${ns}: already Registered"
      continue
    fi

    echo "--- Registering provider: ${ns} (current: ${state}) ---"
    az provider register --namespace "${ns}" --output none

    attempt=0
    while true; do
      state="$(az provider show --namespace "${ns}" --query registrationState -o tsv 2>/dev/null || echo "Unknown")"
      if [[ "${state}" == "Registered" ]]; then
        echo "Provider ${ns}: Registered"
        break
      fi
      attempt=$((attempt + 1))
      if [[ "${attempt}" -ge "${max_attempts}" ]]; then
        echo "Timed out waiting for ${ns} (last state: ${state})."
        exit 1
      fi
      echo "  waiting... (${state}) [${attempt}/${max_attempts}]"
      sleep 5
    done
  done
}

confirm() {
  local prompt="$1"
  read -r -p "${prompt} [y/N] " reply
  case "${reply}" in
    y|Y|yes|YES) return 0 ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
}

create_resource_group() {
  echo "--- Creating resource group: ${RESOURCE_GROUP_NAME} (${LOCATION}) ---"
  az group create \
    --name "${RESOURCE_GROUP_NAME}" \
    --location "${LOCATION}" \
    --output table
}

create_openai_account() {
  echo "--- Creating Azure AI Services account: ${COG_SERVICES_ACCOUNT_NAME} ---"
  echo "    kind=${COG_SERVICES_KIND}  sku=${COG_SERVICES_SKU}"
  if [[ "${COG_SERVICES_KIND}" != "AIServices" ]]; then
    echo "Warning: classic chat.py needs kind=AIServices (got '${COG_SERVICES_KIND}')."
    echo "         OpenAI-kind accounts cannot be linked as AZURE_AI_SERVICES connections."
  fi

  if az cognitiveservices account show \
      --name "${COG_SERVICES_ACCOUNT_NAME}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --output none 2>/dev/null; then
    echo "Account already exists — skipping create."
    return 0
  fi

  az cognitiveservices account create \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --location "${LOCATION}" \
    --kind "${COG_SERVICES_KIND}" \
    --sku "${COG_SERVICES_SKU}" \
    --custom-domain "${COG_SERVICES_ACCOUNT_NAME}" \
    --yes \
    --output table
}

create_hub() {
  echo "--- Creating classic Foundry hub: ${HUB_NAME} ---"

  if az ml workspace show \
      --name "${HUB_NAME}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --output none 2>/dev/null; then
    echo "Hub already exists — skipping create."
    return 0
  fi

  az ml workspace create \
    --kind hub \
    --name "${HUB_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --location "${LOCATION}" \
    --output table
}

hub_resource_id() {
  az ml workspace show \
    --name "${HUB_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query id -o tsv
}

create_project() {
  echo "--- Creating classic hub project: ${PROJECT_NAME} ---"

  if az ml workspace show \
      --name "${PROJECT_NAME}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --output none 2>/dev/null \
    || az resource show \
      --name "${PROJECT_NAME}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --resource-type Microsoft.MachineLearningServices/workspaces \
      --output none 2>/dev/null; then
    echo "Project already exists — skipping create."
    return 0
  fi

  local hub_id subscription_id tmp_yaml tmp_body
  hub_id="$(hub_resource_id)"
  subscription_id="$(az account show --query id -o tsv)"
  echo "    hub-id=${hub_id}"

  # Some ml extension versions fail with:
  #   associatedResourcePNA = PublicNetworkAccessType.ENABLED (invalid)
  # Prefer YAML + Enabled, then ARM REST fallback.
  tmp_yaml="$(mktemp -t hub-project.XXXXXX.yml)"
  cat > "${tmp_yaml}" <<EOF
\$schema: https://azuremlschemas.azureedge.net/latest/workspace.schema.json
name: ${PROJECT_NAME}
kind: project
location: ${LOCATION}
hub_id: ${hub_id}
public_network_access: Enabled
description: Lesson 1 classic Foundry hub project
EOF

  set +e
  az ml workspace create \
    --file "${tmp_yaml}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --public-network-access Enabled \
    --output table
  local rc=$?
  set -e
  rm -f "${tmp_yaml}"

  if [[ "${rc}" -ne 0 ]]; then
    echo "CLI project create failed (ml-extension PNA enum bug is common)."
    echo "--- Creating project via ARM REST (publicNetworkAccess=Enabled) ---"

    tmp_body="$(mktemp -t hub-project.XXXXXX.json)"
    cat > "${tmp_body}" <<EOF
{
  "location": "${LOCATION}",
  "kind": "Project",
  "identity": { "type": "SystemAssigned" },
  "properties": {
    "friendlyName": "${PROJECT_NAME}",
    "description": "Lesson 1 classic Foundry hub project",
    "hubResourceId": "${hub_id}",
    "publicNetworkAccess": "Enabled"
  }
}
EOF

    az rest --method put \
      --uri "https://management.azure.com/subscriptions/${subscription_id}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.MachineLearningServices/workspaces/${PROJECT_NAME}?api-version=2024-07-01-preview" \
      --headers "Content-Type=application/json" \
      --body @"${tmp_body}" \
      --output none
    rm -f "${tmp_body}"
  fi

  local attempt=0
  while ! az resource show \
      --name "${PROJECT_NAME}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --resource-type Microsoft.MachineLearningServices/workspaces \
      --output none 2>/dev/null; do
    attempt=$((attempt + 1))
    if [[ "${attempt}" -ge 36 ]]; then
      echo "Timed out waiting for project '${PROJECT_NAME}'."
      exit 1
    fi
    echo "  waiting for project provisioning... [${attempt}/36]"
    sleep 5
  done
  echo "Project '${PROJECT_NAME}' is ready."
}

# Classic hub connection string:
#   <hostname>;<subscriptionId>;<resourceGroup>;<projectName>
# hostname = discovery_url without https:// and /discovery
build_connection_string() {
  local discovery hostname subscription_id
  discovery="$(az ml workspace show \
    --name "${PROJECT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query discovery_url -o tsv)"

  if [[ -z "${discovery}" || "${discovery}" == "null" ]]; then
    echo "Could not read discovery_url for project '${PROJECT_NAME}'." >&2
    return 1
  fi

  hostname="${discovery#https://}"
  hostname="${hostname#http://}"
  hostname="${hostname%/discovery}"
  hostname="${hostname%/}"

  subscription_id="$(az account show --query id -o tsv)"
  printf '%s;%s;%s;%s\n' \
    "${hostname}" \
    "${subscription_id}" \
    "${RESOURCE_GROUP_NAME}" \
    "${PROJECT_NAME}"
}

write_connection_string_to_env() {
  local conn_str="$1"
  ENV_FILE="${ENV_FILE}" CONN_STR="${conn_str}" python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["ENV_FILE"])
conn = os.environ["CONN_STR"]
key = "AZURE_PROJECT_CONNECTION_STRING"
line = f'{key}="{conn}"'
text = path.read_text()
pattern = re.compile(rf"^{re.escape(key)}=.*$", re.M)
if pattern.search(text):
    text = pattern.sub(line, text, count=1)
else:
    if not text.endswith("\n"):
        text += "\n"
    text += line + "\n"
path.write_text(text)
print(f"Updated {path} → {key}")
PY
}

cmd_connection_string() {
  echo "--- Classic hub project connection string ---"
  local conn_str
  conn_str="$(build_connection_string)"
  echo "${conn_str}"
  write_connection_string_to_env "${conn_str}"
  echo
  echo "Also set in your shell for this session:"
  echo "  export AZURE_PROJECT_CONNECTION_STRING='${conn_str}'"
}

create_openai_hub_connection() {
  # Required by azure-ai-projects get_chat_completions_client():
  # default connection type must be AZURE_AI_SERVICES (account kind=AIServices).
  local conn_name="${AI_SERVICES_CONNECTION_NAME:-azure-ai-services-connection}"
  local endpoint api_key resource_id tmp_yaml

  echo "--- Connecting AI Services to hub (connection: ${conn_name}) ---"

  if az ml connection show \
      --name "${conn_name}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --workspace-name "${HUB_NAME}" \
      --output none 2>/dev/null; then
    echo "Connection already exists — skipping."
    return 0
  fi

  endpoint="$(az cognitiveservices account show \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query properties.endpoint -o tsv)"

  api_key="$(az cognitiveservices account keys list \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query key1 -o tsv)"

  resource_id="$(az cognitiveservices account show \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --query id -o tsv)"

  tmp_yaml="$(mktemp -t aiservices-conn.XXXXXX.yml)"
  cat > "${tmp_yaml}" <<EOF
name: ${conn_name}
type: azure_ai_services
endpoint: ${endpoint}
api_key: ${api_key}
ai_services_resource_id: ${resource_id}
EOF

  if az ml connection create \
      --file "${tmp_yaml}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --workspace-name "${HUB_NAME}" \
      --output table; then
    echo "AI Services connection created on hub."
  else
    echo "ERROR: failed to create azure_ai_services connection."
    echo "Account kind must be AIServices (not OpenAI). Check COG_SERVICES_KIND in .env"
    rm -f "${tmp_yaml}"
    return 1
  fi
  rm -f "${tmp_yaml}"
}

cmd_create() {
  register_providers
  create_resource_group
  create_openai_account
  create_hub
  create_project
  create_openai_hub_connection
  cmd_connection_string

  echo
  echo "=== Classic Foundry hub infra ready ==="
  echo "Resource group : ${RESOURCE_GROUP_NAME}"
  echo "AI Services    : ${COG_SERVICES_ACCOUNT_NAME} (kind=${COG_SERVICES_KIND})"
  echo "Hub            : ${HUB_NAME}"
  echo "Project        : ${PROJECT_NAME}"
  echo "Connection     : ${AI_SERVICES_CONNECTION_NAME:-azure-ai-services-connection}"
  echo "Location       : ${LOCATION}"
  echo
  echo "Next:"
  echo "  ./deploy_model.sh create"
  echo "  ../.venv/bin/python chat.py"
  echo
  echo "Remove later:"
  echo "  ./deploy_infra.sh remove-project"
  echo "  ./deploy_infra.sh remove-hub"
  echo "  ./deploy_infra.sh remove"
}

cmd_remove_project() {
  echo "--- Removing hub project: ${PROJECT_NAME} ---"
  if ! az ml workspace show \
      --name "${PROJECT_NAME}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --output none 2>/dev/null; then
    echo "Project not found — nothing to remove."
    return 0
  fi
  confirm "Delete classic hub project '${PROJECT_NAME}'?"
  az ml workspace delete \
    --name "${PROJECT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --yes \
    --no-wait
  echo "Delete started for project '${PROJECT_NAME}'."
}

cmd_remove_hub() {
  echo "--- Removing classic hub: ${HUB_NAME} ---"
  if ! az ml workspace show \
      --name "${HUB_NAME}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --output none 2>/dev/null; then
    echo "Hub not found — nothing to remove."
    return 0
  fi
  confirm "Delete classic hub '${HUB_NAME}'? (delete projects first if delete fails)"
  az ml workspace delete \
    --name "${HUB_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --yes \
    --no-wait
  echo "Delete started for hub '${HUB_NAME}'."
}

cmd_remove_account() {
  echo "--- Removing OpenAI account: ${COG_SERVICES_ACCOUNT_NAME} ---"
  if ! az cognitiveservices account show \
      --name "${COG_SERVICES_ACCOUNT_NAME}" \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --output none 2>/dev/null; then
    echo "Account not found — nothing to remove."
    return 0
  fi

  confirm "Delete Cognitive Services account '${COG_SERVICES_ACCOUNT_NAME}' (and its model deployments)?"

  az cognitiveservices account delete \
    --name "${COG_SERVICES_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --yes

  echo "Deleted account '${COG_SERVICES_ACCOUNT_NAME}'."
}

cmd_remove() {
  echo "--- Removing resource group: ${RESOURCE_GROUP_NAME} ---"
  if ! az group exists --name "${RESOURCE_GROUP_NAME}" | grep -qi true; then
    echo "Resource group not found — nothing to remove."
    return 0
  fi

  confirm "DELETE resource group '${RESOURCE_GROUP_NAME}' and ALL resources inside it (hub, project, OpenAI, storage, etc.)?"

  az group delete \
    --name "${RESOURCE_GROUP_NAME}" \
    --yes \
    --no-wait

  echo "Delete started for '${RESOURCE_GROUP_NAME}' (running in background)."
}

cmd_help() {
  cat <<EOF
Manage classic Foundry hub infra (Lesson 1)

Usage: ./deploy_infra.sh <command>

Commands:
  create              Create RG + OpenAI + classic hub + project + write connection string
  connection-string   Print connection string and write AZURE_PROJECT_CONNECTION_STRING to .env
  remove-project      Delete hub project only
  remove-hub          Delete classic hub
  remove-account      Delete OpenAI account only
  remove              Delete entire resource group
  help                Show this help

Config: ../.env
Models: ./deploy_model.sh
EOF
}

main() {
  case "${ACTION}" in
    create)
      require_login
      ensure_cli
      cmd_create
      ;;
    connection-string|conn|show-connection)
      require_login
      ensure_cli
      cmd_connection_string
      ;;
    remove-project|delete-project)
      require_login
      ensure_cli
      cmd_remove_project
      ;;
    remove-hub|delete-hub)
      require_login
      ensure_cli
      cmd_remove_hub
      ;;
    remove-account|delete-account)
      require_login
      ensure_cli
      cmd_remove_account
      ;;
    remove|delete|destroy)
      require_login
      ensure_cli
      cmd_remove
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
