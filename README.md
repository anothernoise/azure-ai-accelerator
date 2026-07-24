# Azure AI Accelerator

Hands-on Azure AI samples and accelerators by [anothernoise](https://github.com/anothernoise).

## Modules

| Module | Description |
|--------|-------------|
| [`azure-ai-foundry-legacy-chat`](azure-ai-foundry-legacy-chat/) | Classic Azure AI Foundry **hub** stack (Bicep) + Python chat via `azure-ai-projects` connection string |

## Quick start — classic Foundry chat (dev)

```bash
git clone https://github.com/anothernoise/azure-ai-accelerator.git
cd azure-ai-accelerator

cp .env.example .env.dev
chmod +x azure-ai-foundry-legacy-chat/infra/scripts/*.sh
./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh --env dev --what-if
./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh --env dev

python3 -m venv .venv && source .venv/bin/activate
pip install -r azure-ai-foundry-legacy-chat/requirements.txt
cd azure-ai-foundry-legacy-chat && ENVIRONMENT=dev ../.venv/bin/python chat.py
```

## Structure

```text
azure-ai-accelerator/
  azure-ai-foundry-legacy-chat/
    chat.py                   # Python SDK app
    architecture.md           # diagrams + request flow
    infra/bicep/              # AIServices, classic hub, project
    infra/scripts/            # deploy · refresh-env · remove
    infra_legacy/             # superseded az scripts (reference)
  .env.example
```

## Environments

| Environment | Default RG | Param file | Local config |
|-------------|------------|------------|--------------|
| `dev` | `rg-aialearn-dev-eus` | `environments/dev.bicepparam` | `.env.dev` |
| `test` | `rg-aialearn-test-eus` | `environments/test.bicepparam` | `.env.test` |
| `prod` | `rg-aialearn-prod-eus` | `environments/prod.bicepparam` | `.env.prod` |

```bash
ENVIRONMENT=prod ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh
ENVIRONMENT=prod ./azure-ai-foundry-legacy-chat/infra/scripts/destroy.sh
```

## Docs

- [azure-ai-foundry-legacy-chat/readme.md](azure-ai-foundry-legacy-chat/readme.md) — deploy walkthrough
- [azure-ai-foundry-legacy-chat/architecture.md](azure-ai-foundry-legacy-chat/architecture.md) — architecture + Mermaid diagrams
- [azure-ai-foundry-legacy-chat/infra/README.md](azure-ai-foundry-legacy-chat/infra/README.md) — day-2 ops

## License

[MIT](LICENSE)
