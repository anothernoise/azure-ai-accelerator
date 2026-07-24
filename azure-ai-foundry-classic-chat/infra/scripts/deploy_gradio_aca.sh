#!/usr/bin/env bash
# Deploy Gradio UI to Azure Container Instances (same RG as classic-chat).
#
# Usage (from repo root):
#   ./azure-ai-foundry-classic-chat/infra/scripts/deploy_gradio_aca.sh --env dev
#
# Prerequisites: az login, Docker Desktop (Free Trial blocks az acr build),
# classic-chat already deployed (.env.dev).
#
# Why ACI: Free Trial often has 0 App Service VM quota (B1 fails) and Container Apps
# managed environments can stick in Waiting. ACI works with the image already in ACR.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
common_init

MODULE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENVIRONMENT="${ENVIRONMENT:-dev}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENVIRONMENT="$2"; RG_NAME="rg-${WORKLOAD}-${ENVIRONMENT}-${REGION_SHORT}"; shift 2 ;;
    -h|--help)
      echo "Usage: deploy_gradio_aca.sh [--env dev|test|prod]"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

validate_environment
require_login
resolve_resource_group
load_env_file

RG_NAME="${RESOURCE_GROUP_NAME:-${RG_NAME}}"
LOCATION="${LOCATION:-eastus}"
ACR_NAME="${ACR_NAME:-acraialearn${ENVIRONMENT}$(printf '%s' "${RG_NAME}" | tr -cd 'a-z0-9' | md5 2>/dev/null | cut -c1-6 || openssl rand -hex 3)}"
ACI_NAME="${ACI_NAME:-aci-aialearn-gradio-${ENVIRONMENT}}"
DNS_LABEL="${DNS_LABEL:-aialearngradio${ENVIRONMENT}$(printf '%s' "${RG_NAME}" | tr -cd 'a-z0-9' | md5 2>/dev/null | cut -c1-6)}"
IMAGE_NAME="classic-chat-gradio"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "=== Deploy Gradio → Azure Container Instances ==="
echo "  RG:       ${RG_NAME}"
echo "  ACR:      ${ACR_NAME}"
echo "  ACI:      ${ACI_NAME}"
echo "  DNS:      ${DNS_LABEL}"
echo "  Module:   ${MODULE_DIR}"

: "${AZURE_PROJECT_CONNECTION_STRING:?missing in env file}"
: "${DEPLOYMENT_NAME:?missing}"
: "${PROJECT_NAME:?missing}"
: "${HUB_NAME:?missing}"
: "${COG_SERVICES_ACCOUNT_NAME:?missing}"

echo "--- Providers ---"
for ns in Microsoft.ContainerInstance Microsoft.ContainerRegistry; do
  state="$(az provider show -n "${ns}" --query registrationState -o tsv 2>/dev/null || echo Unknown)"
  if [[ "${state}" != "Registered" ]]; then
    echo "Registering ${ns}..."
    az provider register -n "${ns}" --wait --output none
  fi
done

echo "--- ACR ---"
if ! az acr show -g "${RG_NAME}" -n "${ACR_NAME}" --output none 2>/dev/null; then
  az acr create -g "${RG_NAME}" -n "${ACR_NAME}" --sku Basic --admin-enabled true -o table
else
  az acr update -g "${RG_NAME}" -n "${ACR_NAME}" --admin-enabled true -o none
fi
ACR_LOGIN_SERVER="$(az acr show -g "${RG_NAME}" -n "${ACR_NAME}" --query loginServer -o tsv)"
ACR_USER="$(az acr credential show -n "${ACR_NAME}" -g "${RG_NAME}" --query username -o tsv)"
ACR_PASS="$(az acr credential show -n "${ACR_NAME}" -g "${RG_NAME}" --query 'passwords[0].value' -o tsv)"
IMAGE_REF="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

# Reuse image if already in ACR; otherwise build linux/amd64
NEED_BUILD=1
if az acr repository show -n "${ACR_NAME}" --image "${IMAGE_NAME}:${IMAGE_TAG}" --output none 2>/dev/null; then
  echo "--- Image already in ACR: ${IMAGE_REF} ---"
  NEED_BUILD=0
fi

if [[ "${NEED_BUILD}" -eq 1 ]]; then
  echo "--- Build & push image (linux/amd64) ---"
  build_ok=0
  if az acr build \
    --registry "${ACR_NAME}" \
    --image "${IMAGE_NAME}:${IMAGE_TAG}" \
    --platform linux/amd64 \
    --file "${MODULE_DIR}/Dockerfile" \
    "${MODULE_DIR}" \
    -o table 2>/tmp/acr_build_err.txt; then
    build_ok=1
  else
    if grep -qi 'TasksOperationsNotAllowed\|not permitted' /tmp/acr_build_err.txt; then
      echo "ACR Tasks not allowed — building with local Docker (linux/amd64)."
    else
      cat /tmp/acr_build_err.txt >&2 || true
      echo "az acr build failed — trying local Docker..."
    fi
  fi
  if [[ "${build_ok}" -ne 1 ]]; then
    if ! docker info >/dev/null 2>&1; then
      echo "Docker is not running. Start Docker Desktop, then re-run this script."
      exit 1
    fi
    docker buildx build --platform linux/amd64 --load \
      -t "${IMAGE_REF}" -f "${MODULE_DIR}/Dockerfile" "${MODULE_DIR}"
    echo "${ACR_PASS}" | docker login "${ACR_LOGIN_SERVER}" -u "${ACR_USER}" --password-stdin
    docker push "${IMAGE_REF}"
  fi
fi

echo "--- Container Instance ---"
if az container show -g "${RG_NAME}" -n "${ACI_NAME}" --output none 2>/dev/null; then
  echo "Deleting existing ACI ${ACI_NAME}..."
  az container delete -g "${RG_NAME}" -n "${ACI_NAME}" --yes -o none
fi

# Secure env for connection string; plain env for the rest
az container create \
  -g "${RG_NAME}" \
  -n "${ACI_NAME}" \
  --image "${IMAGE_REF}" \
  --registry-login-server "${ACR_LOGIN_SERVER}" \
  --registry-username "${ACR_USER}" \
  --registry-password "${ACR_PASS}" \
  --cpu 1 \
  --memory 1.5 \
  --os-type Linux \
  --ports 7860 \
  --protocol TCP \
  --dns-name-label "${DNS_LABEL}" \
  --assign-identity \
  --restart-policy OnFailure \
  --environment-variables \
    ENVIRONMENT="${ENVIRONMENT}" \
    ENVIRONMENT_NAME="${ENVIRONMENT}" \
    DEPLOYMENT_NAME="${DEPLOYMENT_NAME}" \
    PROJECT_NAME="${PROJECT_NAME}" \
    AI_SERVICES_CONNECTION_NAME="${AI_SERVICES_CONNECTION_NAME:-}" \
    RESOURCE_GROUP_NAME="${RG_NAME}" \
    COG_SERVICES_ACCOUNT_NAME="${COG_SERVICES_ACCOUNT_NAME}" \
    GRADIO_SERVER_NAME=0.0.0.0 \
    GRADIO_SERVER_PORT=7860 \
  --secure-environment-variables \
    AZURE_PROJECT_CONNECTION_STRING="${AZURE_PROJECT_CONNECTION_STRING}" \
  -o table

PRINCIPAL_ID="$(az container show -g "${RG_NAME}" -n "${ACI_NAME}" --query identity.principalId -o tsv)"
PROJECT_ID="$(az resource show -g "${RG_NAME}" -n "${PROJECT_NAME}" \
  --resource-type Microsoft.MachineLearningServices/workspaces --query id -o tsv)"
HUB_ID="$(az resource show -g "${RG_NAME}" -n "${HUB_NAME}" \
  --resource-type Microsoft.MachineLearningServices/workspaces --query id -o tsv)"
AIS_ID="$(az cognitiveservices account show -g "${RG_NAME}" -n "${COG_SERVICES_ACCOUNT_NAME}" --query id -o tsv)"

echo "--- Roles for system managed identity ---"
for scope in "${PROJECT_ID}" "${HUB_ID}"; do
  az role assignment create \
    --assignee-object-id "${PRINCIPAL_ID}" \
    --assignee-principal-type ServicePrincipal \
    --role "Azure AI Developer" \
    --scope "${scope}" \
    --output none 2>/dev/null || true
done
az role assignment create \
  --assignee-object-id "${PRINCIPAL_ID}" \
  --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services User" \
  --scope "${AIS_ID}" \
  --output none 2>/dev/null || true
az role assignment create \
  --assignee-object-id "${PRINCIPAL_ID}" \
  --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services OpenAI User" \
  --scope "${AIS_ID}" \
  --output none 2>/dev/null || true

FQDN="$(az container show -g "${RG_NAME}" -n "${ACI_NAME}" --query ipAddress.fqdn -o tsv)"
STATE="$(az container show -g "${RG_NAME}" -n "${ACI_NAME}" --query instanceView.state -o tsv 2>/dev/null || echo pending)"

echo
echo "=== Gradio deployed ==="
echo "  URL:   http://${FQDN}:7860"
echo "  State: ${STATE}"
echo "  Wait ~1–2 min for pull + RBAC, then open the URL (HTTP on port 7860)."
echo "  Logs:  az container logs -g ${RG_NAME} -n ${ACI_NAME}"
echo "  Status: az container show -g ${RG_NAME} -n ${ACI_NAME} --query instanceView.state -o tsv"
echo
echo "Remove later:"
echo "  az container delete -g ${RG_NAME} -n ${ACI_NAME} --yes"
echo "  az acr delete -g ${RG_NAME} -n ${ACR_NAME} --yes"
