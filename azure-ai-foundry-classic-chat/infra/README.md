# Infra — Bicep (classic Foundry hub)

Declarative Azure infra for Lesson 1 classic hub + AI Services.

```text
azure-ai-foundry-classic-chat/infra/
  bicep/
    main.bicep
    environments/             # dev | test | prod parameter files
    modules/
  scripts/
    deploy.sh                 # RG + az deployment + .env.{env}
    refresh-env.sh            # refresh .env from last ARM deployment
    remove.sh                 # granular delete (project / hub / account / RG)
    destroy.sh                # alias → remove.sh remove
    write_env.py              # map outputs → env file
    load_env.py               # load .env.{ENVIRONMENT} in Python
    deploy_model.py           # model CRUD outside Bicep
    common.sh                 # shared helpers
```

Legacy shell stack: `azure-ai-foundry-classic-chat/infra_legacy/scripts/` (reference only — keep at module root, not under `infra/`).

See also [../architecture.md](../architecture.md) for diagrams and system design.

## Environment best practices

| Concern | dev | test | prod |
|---------|-----|------|------|
| Resource group | `rg-aialearn-dev-eus` | `rg-aialearn-test-eus` | `rg-aialearn-prod-eus` |
| Config file | `.env.dev` | `.env.test` | `.env.prod` |
| Deploy guard | none | none | confirmation prompt |
| Destroy guard | y/N | y/N | type RG name |
| Tags | `env=dev` | `env=test` | `env=prod`, `criticality=production` |

## Deploy

```bash
chmod +x azure-ai-foundry-classic-chat/infra/scripts/*.sh

./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev --what-if
./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev
ENVIRONMENT=prod ./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh
```

Writes `.env.{environment}` and copies to `.env`.

## Day-2 operations

### Refresh local config (no redeploy)

Re-read ARM deployment outputs into `.env.{env}`:

```bash
./azure-ai-foundry-classic-chat/infra/scripts/refresh-env.sh --env dev
./azure-ai-foundry-classic-chat/infra/scripts/refresh-env.sh --env dev --live-connection   # rebuild connection string from portal
./azure-ai-foundry-classic-chat/infra/scripts/refresh-env.sh --env dev --deployment aialearn-dev-20250723120000
```

### Change model / capacity (no full infra redeploy)

Edit `.env.{env}` or Bicep params, then:

```bash
ENVIRONMENT=dev ../.venv/bin/python azure-ai-foundry-classic-chat/infra/scripts/deploy_model.py update
ENVIRONMENT=dev ../.venv/bin/python azure-ai-foundry-classic-chat/infra/scripts/deploy_model.py show
ENVIRONMENT=dev ../.venv/bin/python azure-ai-foundry-classic-chat/infra/scripts/deploy_model.py list
ENVIRONMENT=dev ../.venv/bin/python azure-ai-foundry-classic-chat/infra/scripts/deploy_model.py delete
ENVIRONMENT=dev ../.venv/bin/python azure-ai-foundry-classic-chat/infra/scripts/deploy_model.py delete-all
```

Or change `environments/dev.bicepparam` and redeploy — Bicep is idempotent for model updates.

### Remove / delete resources

Granular (uses names from `.env.{env}`):

```bash
./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-project --env dev
./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-hub --env dev
./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove-account --env dev
./azure-ai-foundry-classic-chat/infra/scripts/remove.sh remove --env dev      # entire RG
./azure-ai-foundry-classic-chat/infra/scripts/destroy.sh --env dev            # same as remove
```

Order for partial teardown: **project → hub → account**. Fastest cleanup: `remove --env dev`.

## Robustness

| Behavior | Detail |
|----------|--------|
| Provider registration | Polls up to 60×5s per namespace, incl. `Microsoft.OperationalInsights` (required for App Insights) |
| Bicep redeploy | Safe to re-run; change params in `environments/*.bicepparam` then `deploy.sh` |
| Project create failures | Bicep uses ARM directly (`publicNetworkAccess: Enabled`). If deploy fails, check Azure portal / re-run deploy; legacy `infra_legacy` ARM fallback remains as reference |
| Prod guards | Deploy, delete, and model delete prompt in prod |

## Intentionally not ported from legacy

These legacy patterns were dropped on purpose:

| Legacy | Why not in Bicep stack |
|--------|------------------------|
| `az extension add -n ml` on deploy | Bicep deploy uses ARM; ML extension only needed for **delete** of hub/project |
| Separate infra + model steps | Model ships in Bicep (`deployModel=true`) |
| `COG_SERVICES_KIND=OpenAI` option | Classic SDK requires `AIServices` |
| Bare hub (no storage/KV) | Bicep attaches proper hub dependencies |
| Hand-edited resource names in `.env` | Names come from CAF module + deploy outputs |

## Run lesson app

```bash
cd azure-ai-foundry-classic-chat
ENVIRONMENT=dev ../.venv/bin/python chat.py
```

## Naming (CAF abbreviations)

| Resource | Pattern | Example (dev) |
|----------|---------|---------------|
| Resource group | `rg-<workload>-<env>-<region>` | `rg-aialearn-dev-eus` |
| AI Services | `ais-<workload>-<env>-<region>-<suffix>` | `ais-aialearn-dev-eus-x7k2q` |
| Hub | `aih-<workload>-<env>-<region>` | `aih-aialearn-dev-eus` |
| Project | `proj-<workload>-<env>-<region>` | `proj-aialearn-dev-eus` |
