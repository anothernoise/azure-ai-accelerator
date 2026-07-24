# Azure AI Accelerator

**Reusable Azure AI patterns you can deploy, run, and extend** — starting with classic Azure AI Foundry (hub projects), Bicep infrastructure, and working Python samples.

> Maintained by [anothernoise](https://github.com/anothernoise) · [MIT License](LICENSE)

---

## When to use which module

| Goal | Use | Skip / see instead |
|------|-----|---------------------|
| Learn classic **hub + project** + Bicep | [`azure-ai-foundry-classic-chat`](azure-ai-foundry-classic-chat/) | — |
| Thin SDK chat (`connection string`) | `chat.py` in classic-chat | — |
| Prompt Flow flex / prompty lab | `chat-prompt-flow.py` (retires **2027-04-20**) | Prefer Agents for new work |
| Local chat **UI** | Gradio `app_gradio.py` (+ optional Docker) | Full hosted ACA template |
| Classic **Agents** (threads / runs) | [`azure-ai-foundry-classic-agents`](azure-ai-foundry-classic-agents/) | — |
| Hosted web chat + optional **RAG** + `azd up` | [Azure-Samples/get-started-with-ai-chat](https://github.com/Azure-Samples/get-started-with-ai-chat) | Don’t bloat classic-chat |
| New Foundry portal / Agent Service GA | *(planned module)* | Classic modules above |

Gap analysis vs the Azure sample: [docs/gap-analysis-get-started-with-ai-chat.md](docs/gap-analysis-get-started-with-ai-chat.md)

---

## Why this exists

Azure AI evolves quickly (classic Foundry hubs vs. new Foundry, connection types, model deprecations). This accelerator captures **working, opinionated setups** that:

- Prefer **Bicep** over one-off portal clicks
- Separate **dev / test / prod** with CAF-style naming
- Keep **secrets out of git** (`.env.{environment}` generated after deploy)
- Document **architecture and request flows** with Mermaid diagrams
- Include **deploy, refresh, and teardown** scripts — not just a happy-path create

---

## Modules

| Module | Status | What you get |
|--------|--------|----------------|
| [`azure-ai-foundry-classic-chat`](azure-ai-foundry-classic-chat/) | Ready | Classic hub + project, Bicep, `chat.py`, optional Prompt Flow + Gradio/Docker |
| [`azure-ai-foundry-classic-agents`](azure-ai-foundry-classic-agents/) | Ready | Agents sample on the **same** hub project (no second stack) |

---

## Prerequisites

| Tool | Notes |
|------|--------|
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | Logged in with a subscription that can create Cognitive Services + Azure ML workspaces |
| Azure subscription | Free Trial works for learning; watch quotas and spending limits |
| Python 3.10+ | For sample apps |
| Bicep | Installed automatically via `az bicep` / deploy scripts |
| Docker (optional) | Only for Gradio container |

```bash
az login
az account set --subscription "<subscription-id>"
az account show -o table
```

---

## Quick start

```bash
git clone https://github.com/anothernoise/azure-ai-accelerator.git
cd azure-ai-accelerator

cp .env.example .env.dev
chmod +x azure-ai-foundry-classic-chat/infra/scripts/*.sh

./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev --what-if
./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev

python3 -m venv .venv && source .venv/bin/activate
pip install -r azure-ai-foundry-classic-chat/requirements.txt

cd azure-ai-foundry-classic-chat
ENVIRONMENT=dev ../.venv/bin/python chat.py
```

Optional UI:

```bash
pip install -r azure-ai-foundry-classic-chat/requirements-ui.txt
ENVIRONMENT=dev ../.venv/bin/python app_gradio.py
# open http://127.0.0.1:7860
```

Optional Agents (same `.env.dev`):

```bash
cd ../azure-ai-foundry-classic-agents
ENVIRONMENT=dev ../.venv/bin/python agent_chat.py
```

---

## Repository layout

```text
azure-ai-accelerator/
├── README.md
├── LICENSE
├── docs/
│   └── gap-analysis-get-started-with-ai-chat.md
├── .env.example
├── azure-ai-foundry-classic-chat/
│   ├── chat.py                 # SDK chat
│   ├── chat-prompt-flow.py     # Prompt Flow (EOL 2027)
│   ├── app_gradio.py           # optional Gradio UI
│   ├── Dockerfile              # optional container for Gradio
│   ├── prompt_flow/
│   ├── infra/bicep + scripts/
│   └── infra_legacy/           # old az scripts (reference only)
└── azure-ai-foundry-classic-agents/
    └── agent_chat.py
```

---

## Environment model

| Environment | Default RG | Param file | Local config |
|-------------|------------|------------|--------------|
| `dev` | `rg-aialearn-dev-eus` | `environments/dev.bicepparam` | `.env.dev` |
| `test` | `rg-aialearn-test-eus` | `environments/test.bicepparam` | `.env.test` |
| `prod` | `rg-aialearn-prod-eus` | `environments/prod.bicepparam` | `.env.prod` |

```bash
ENVIRONMENT=prod ./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh
ENVIRONMENT=prod ./azure-ai-foundry-classic-chat/infra/scripts/destroy.sh
```

---

## Documentation

| Doc | Purpose |
|-----|---------|
| [azure-ai-foundry-classic-chat/readme.md](azure-ai-foundry-classic-chat/readme.md) | Deploy walkthrough |
| [azure-ai-foundry-classic-chat/architecture.md](azure-ai-foundry-classic-chat/architecture.md) | Topology + chat.py flow |
| [azure-ai-foundry-classic-chat/prompt_flow/README.md](azure-ai-foundry-classic-chat/prompt_flow/README.md) | Prompt Flow architecture |
| [azure-ai-foundry-classic-agents/readme.md](azure-ai-foundry-classic-agents/readme.md) | Agents sample |
| [docs/gap-analysis-get-started-with-ai-chat.md](docs/gap-analysis-get-started-with-ai-chat.md) | vs Azure Samples chat template |

Microsoft: [Classic hub get-started](https://learn.microsoft.com/en-us/azure/foundry-classic/quickstarts/hub-get-started-code)

> Classic portal: [ai.azure.com](https://ai.azure.com) with **New Foundry** toggle **off**.

---

## Safety & cost notes

- Deploy only to a subscription you control; review free-trial quotas.
- Default stack includes AI Services, storage, Key Vault, App Insights, hub, and project — tear down with `destroy.sh` when idle.
- Never commit `.env` or `.env.*` (only `.env.example`).
- Gradio Dockerfile is for **local/demo** containerization — not a full production ACA template (see Azure sample for that).

---

## Roadmap

- [ ] New Foundry (non-hub) / Agent Service GA module
- [ ] Optional RAG module (AI Search) as a sibling
- [ ] CI: Bicep what-if on PRs

---

## Author

**Dmitry** ([@anothernoise](https://github.com/anothernoise)) · [shirokoff.ca](https://shirokoff.ca)

## License

[MIT](LICENSE)
