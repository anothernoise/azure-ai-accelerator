# azure-ai-foundry-classic-chat — Classic Foundry hub chat

Module of [azure-ai-accelerator](https://github.com/anothernoise/azure-ai-accelerator).

Based on: [Quickstart: Get started with Microsoft Foundry (Hub projects)](https://learn.microsoft.com/en-us/azure/foundry-classic/quickstarts/hub-get-started-code)

Architecture diagrams: [architecture.md](architecture.md)

**Goal:** provision classic hub infra with **Bicep**, then call a chat model from Python using `azure-ai-projects==1.0.0b10` and a **project connection string**.

> Use the **classic** portal: [ai.azure.com](https://ai.azure.com) with **New Foundry** toggle **off**.  
> This lesson is **not** the new Foundry resource (`*.services.ai.azure.com`).

## What you build

| Layer | Tool | Creates / does |
|-------|------|----------------|
| Infra | Bicep (`infra/bicep`) | RG, AI Services, storage, Key Vault, classic hub, hub project, AIServices connection, model deployment |
| Glue | `infra/scripts/deploy.sh` | `az deployment` + writes `.env.{environment}` |
| App | `chat.py` | Calls the model via `AIProjectClient` |

## Layout

| Path | Role |
|------|------|
| `infra/bicep/` | Infra as code (CAF naming) — see [infra/README.md](infra/README.md) |
| `infra/bicep/environments/` | `dev`, `test`, `prod` parameter files |
| `infra/scripts/deploy.sh` | Deploy wrapper (`--env dev\|test\|prod`) |
| `infra/scripts/refresh-env.sh` | Sync `.env.{env}` from ARM outputs (no redeploy) |
| `infra/scripts/remove.sh` | Granular delete (project / hub / account / RG) |
| `../.env.dev` / `../.env.prod` | Per-environment runtime config (generated) |
| `chat.py` | Lesson app (SDK connection string) |
| `chat-prompt-flow.py` | Optional Prompt Flow sample (retires 2027-04-20) |
| `prompt_flow/` | Flex flow + prompty used by `chat-prompt-flow.py` |
| `app_gradio.py` | Optional Gradio chat UI (same SDK path as `chat.py`) |
| `Dockerfile` / `docker-compose.yml` | Optional containerization for Gradio |
| `infra_legacy/scripts/` | Legacy `az` scripts (reference only — do not use for new deploys) |

---

## Deploy walkthrough (dev)

All commands below assume repo root unless noted.

### Prerequisites (one-time)

```bash
cd /path/to/azure-ai-accelerator

# Azure CLI
az login
az account set --subscription "<your-subscription-id>"
az account show -o table

# Python venv
python3 -m venv .venv
source .venv/bin/activate
pip install -r azure-ai-foundry-classic-chat/requirements.txt

# Scripts
chmod +x azure-ai-foundry-classic-chat/infra/scripts/*.sh
```

Optional — deploy will overwrite generated values:

```bash
cp .env.example .env.dev
```

Edit Bicep inputs if needed (region, model, capacity):

- `azure-ai-foundry-classic-chat/infra/bicep/environments/dev.bicepparam` — learning / experiments
- `azure-ai-foundry-classic-chat/infra/bicep/environments/prod.bicepparam` — production

> **Note:** If you previously used `infra_legacy/scripts/deploy_infra.sh`, your old `.env` may point at a different RG (e.g. `my-foundry-rg`). The Bicep deploy creates a **new** stack in `rg-aialearn-dev-eus` and writes **`.env.dev`**. Old resources are left untouched unless you delete them.

### Step 1 — Preview (recommended)

From repo root:

```bash
./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev --what-if
```

From `azure-ai-foundry-classic-chat/infra/scripts`:

```bash
./deploy.sh --env dev --what-if
```

Shows what will be created in **`rg-aialearn-dev-eus`** without making changes (~1–3 min).

| Resource | Example name |
|----------|----------------|
| Resource group | `rg-aialearn-dev-eus` |
| AI Services (`kind=AIServices`) | `ais-aialearn-dev-eus-<suffix>` |
| Model deployment | `gpt-5-mini` |
| Classic hub | `aih-aialearn-dev-eus` |
| Hub project | `proj-aialearn-dev-eus` |
| Storage / Key Vault / App Insights | CAF names from Bicep |

### Step 2 — Deploy

From **repo root**:

```bash
./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev
```

Or from **`azure-ai-foundry-classic-chat/infra/scripts`** (where you are after `cd infra/scripts`):

```bash
./deploy.sh --env dev
```

> Do **not** use `/infra/scripts/...` — that is an absolute path from filesystem root and will fail.

What happens:

1. Registers Azure providers (with timeout)
2. Creates `rg-aialearn-dev-eus` in `eastus`
3. Runs Bicep with `environments/dev.bicepparam`
4. Writes **`../.env.dev`** via `write_env.py`
5. Copies `.env.dev` → **`.env`** (active local default)

Full deploy typically takes **5–15 minutes** (hub + project provisioning is slow).

Production:

```bash
ENVIRONMENT=prod ./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh   # prompts for confirmation
```

On success you should see:

```text
Updated .env.dev
  AZURE_PROJECT_CONNECTION_STRING=eastus.api.azureml.ms;...
  RESOURCE_GROUP_NAME=rg-aialearn-dev-eus
  ...
```

### Step 3 — Run chat

```bash
cd azure-ai-foundry-classic-chat
ENVIRONMENT=dev ../.venv/bin/python chat.py
```

Expected output:

```text
Using environment: dev
<assistant response>
```

> Use `../.venv/bin/python` — a shell `python` alias (e.g. Homebrew) can miss venv packages (`ModuleNotFoundError: dotenv`).

### Optional — Prompt Flow chat

> **Retirement:** Prompt Flow retires **April 20, 2027** and is not recommended for new development. Prefer [Foundry Agents / Agent Framework](https://learn.microsoft.com/en-us/azure/foundry-classic/concepts/prompt-flow). This sample is for classic-hub learning only.

```bash
ENVIRONMENT=dev ../.venv/bin/python chat-prompt-flow.py

PROMPT_FLOW_QUESTION="What is a classic Foundry hub?" \
  ENVIRONMENT=dev ../.venv/bin/python chat-prompt-flow.py
```

Uses the same AI Services account from `.env.{env}`, creates a **local** Prompt Flow connection (`aialearn_aoai_connection`) via `az cognitiveservices … keys`, then runs the flex flow under `prompt_flow/`.

### Optional — Gradio UI (+ Docker / Azure)

**Local**

```bash
# UI extras (separate from Prompt Flow deps)
pip install -r requirements-ui.txt
ENVIRONMENT=dev ../.venv/bin/python app_gradio.py
# → http://127.0.0.1:7860
```

**Docker (local)**

```bash
# from this module directory; mounts repo root for .env.dev
docker compose up --build
# or:
docker build -t classic-chat-gradio .
docker run --rm -p 7860:7860 -e CONFIG_ROOT=/config -e ENVIRONMENT=dev \
  -v "$(pwd)/..:/config:ro" classic-chat-gradio
```

**Azure Container Instances** (public HTTP URL on port 7860)

Prerequisites: classic-chat Bicep stack deployed (`.env.dev`). Docker Desktop only needed the first time (Free Trial blocks `az acr build`; image is built as `linux/amd64` and pushed to ACR).

```bash
# from repo root
./azure-ai-foundry-classic-chat/infra/scripts/deploy_gradio_aca.sh --env dev
# prints: http://aialearngradiodev….eastus.azurecontainer.io:7860
```

| Resource | Example name |
|----------|----------------|
| Azure Container Registry | `acraialearndev…` |
| Container Instance (Gradio) | `aci-aialearn-gradio-dev` |

Auth: system managed identity gets **Azure AI Developer** on hub/project and Cognitive Services roles on the AI Services account; connection string is a secure env var.

```bash
az container logs -g rg-aialearn-dev-eus -n aci-aialearn-gradio-dev
az container show -g rg-aialearn-dev-eus -n aci-aialearn-gradio-dev --query ipAddress.fqdn -o tsv
```

> Free Trial often has **0 App Service B1 quota** and Container Apps envs can stick in `Waiting`, so this path uses ACI.

This is a **demo** packaging of Gradio (not a full ACA/RAG template — see [gap analysis](../docs/gap-analysis-get-started-with-ai-chat.md)).

### Step 4 — Verify in portal

1. Open [ai.azure.com](https://ai.azure.com)
2. **New Foundry OFF** (classic)
3. Open project **`proj-aialearn-dev-eus`**
4. Overview → connection string should match `.env.dev`

---

## Legacy vs new stack

If you ran the old shell scripts earlier, you may have two parallel stacks:

| | Legacy (`infra_legacy`) | New Bicep (`infra/`) |
|---|-------------------------|----------------------|
| Resource group | e.g. `my-foundry-rg` | `rg-aialearn-dev-eus` |
| Hub / project | e.g. `my-foundry-hub` | `aih-aialearn-dev-eus` / `proj-aialearn-dev-eus` |
| Config file | old `.env` values | `.env.dev` → copied to `.env` |

Delete the old RG only when you no longer need it:

```bash
az group delete -n my-foundry-rg --yes --no-wait
```

---

## Key concepts (Lesson 1)

- **Classic hub** = `Microsoft.MachineLearningServices/workspaces` with `kind=Hub`
- **Hub project** = same RP with `kind=Project` + `hubResourceId`
- **Connection string** format:  
  `eastus.api.azureml.ms;<subscriptionId>;<resourceGroup>;<projectName>`
- `get_chat_completions_client()` needs **AIServices** connection (not `OpenAI` kind)
- Use **GenerallyAvailable** models (`gpt-5-mini`)

Config split: **`.bicepparam`** = what to build · **`.env.{env}`** = what was deployed (see [architecture.md](architecture.md))

---

## Follow-up commands

**Refresh config without redeploy** (only works **after** Bicep deploy):

```bash
# repo root
./azure-ai-foundry-classic-chat/infra/scripts/refresh-env.sh --env dev

# or from azure-ai-foundry-classic-chat/infra/scripts
./refresh-env.sh --env dev
```

If you see *“No succeeded ARM deployment”*, run `./deploy.sh --env dev` first — `refresh-env` cannot sync from the legacy `my-foundry-rg` stack.

**Model day-2 (if changed outside Bicep):**

```bash
ENVIRONMENT=dev python azure-ai-foundry-classic-chat/infra/scripts/deploy_model.py list
ENVIRONMENT=dev python azure-ai-foundry-classic-chat/infra/scripts/deploy_model.py show
ENVIRONMENT=dev python azure-ai-foundry-classic-chat/infra/scripts/deploy_model.py update
ENVIRONMENT=dev python azure-ai-foundry-classic-chat/infra/scripts/deploy_model.py delete
```

**Granular remove:**

```bash
./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-project --env dev
./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-hub --env dev
./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-account --env dev
./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove --env dev      # entire RG
```

See [infra/README.md](infra/README.md) for full day-2 reference.

---

## Cleanup

```bash
./azure-ai-foundry-classic-chat/infra/scripts/destroy.sh --env dev
./azure-ai-foundry-classic-chat/infra/scripts/destroy.sh --env prod   # requires typing RG name
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Not logged in` | `az login` → `az account set --subscription "<id>"` |
| `No module named 'dotenv'` | Use `../.venv/bin/python` after `pip install -r requirements.txt` |
| `No env file found` | Run deploy: `./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev` |
| `No connection of type AZURE_AI_SERVICES` | Redeploy Bicep; account must be `kind=AIServices` |
| `ServiceModelDeprecating` | Bicep defaults to `gpt-5-mini`; update `environments/*.bicepparam` if changed |
| `MissingSubscriptionRegistration` | `deploy.sh` registers providers (incl. `Microsoft.OperationalInsights` for App Insights); wait and re-run |
| Deploy fails on hub project | Re-run deploy; see `infra_legacy` ARM fallback for reference |

---

## Next

[Create and manage Foundry agents in VS Code (classic)](https://learn.microsoft.com/en-us/azure/foundry-classic/how-to/develop/vs-code-agents)
