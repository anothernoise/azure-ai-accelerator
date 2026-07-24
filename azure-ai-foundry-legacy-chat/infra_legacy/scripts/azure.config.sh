#!/usr/bin/env bash
# Loads repo-root .env.{ENVIRONMENT} (legacy az scripts).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
ENVIRONMENT="${ENVIRONMENT:-dev}"
ENV_FILE="${REPO_ROOT}/.env.${ENVIRONMENT}"

if [[ ! -f "${ENV_FILE}" ]]; then
  ENV_FILE="${REPO_ROOT}/.env"
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Create from template and deploy:"
  echo "  cp .env.example .env.dev"
  echo "  ENVIRONMENT=dev ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

: "${RESOURCE_GROUP_NAME:?RESOURCE_GROUP_NAME not set in ${ENV_FILE}}"
: "${LOCATION:?LOCATION not set in ${ENV_FILE}}"
: "${COG_SERVICES_ACCOUNT_NAME:?COG_SERVICES_ACCOUNT_NAME not set in ${ENV_FILE}}"
: "${COG_SERVICES_SKU:?COG_SERVICES_SKU not set in ${ENV_FILE}}"
: "${COG_SERVICES_KIND:?COG_SERVICES_KIND not set in ${ENV_FILE}}"
: "${HUB_NAME:?HUB_NAME not set in ${ENV_FILE}}"
: "${PROJECT_NAME:?PROJECT_NAME not set in ${ENV_FILE}}"
: "${DEPLOYMENT_NAME:?DEPLOYMENT_NAME not set in ${ENV_FILE}}"
: "${MODEL_NAME:?MODEL_NAME not set in ${ENV_FILE}}"
: "${MODEL_VERSION:?MODEL_VERSION not set in ${ENV_FILE}}"
: "${MODEL_FORMAT:?MODEL_FORMAT not set in ${ENV_FILE}}"
: "${DEPLOYMENT_SKU_NAME:?DEPLOYMENT_SKU_NAME not set in ${ENV_FILE}}"
: "${DEPLOYMENT_SKU_CAPACITY:?DEPLOYMENT_SKU_CAPACITY not set in ${ENV_FILE}}"
: "${AI_SERVICES_CONNECTION_NAME:=azure-ai-services-connection}"
