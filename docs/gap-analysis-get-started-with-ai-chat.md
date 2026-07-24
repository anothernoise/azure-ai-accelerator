# Gap analysis: azure-ai-foundry-classic-chat vs Azure-Samples/get-started-with-ai-chat

**Date:** 2026-07-24  
**Ours:** [`azure-ai-foundry-classic-chat`](../azure-ai-foundry-classic-chat/) in [azure-ai-accelerator](https://github.com/anothernoise/azure-ai-accelerator)  
**Theirs:** [Azure-Samples/get-started-with-ai-chat](https://github.com/Azure-Samples/get-started-with-ai-chat)

## Executive summary

| Dimension | Ours | Azure sample |
|-----------|------|----------------|
| **Product surface** | Classic Foundry **hub/project** + SDK / Prompt Flow / Gradio | Hosted **chat web app** on Container Apps + Foundry project/tools |
| **Primary UX** | CLI scripts (+ optional Gradio) | Browser UI via ACA |
| **Deploy UX** | Custom `deploy.sh` + Bicep | `azd up` / Copilot `/up` |
| **Scope** | Minimal learning stack | Production-shaped template (RAG optional, monitoring, ACR, ACA) |
| **Auth to models** | Hub connection ApiKey + user AAD (SDK path); local PF ApiKey (Prompt Flow) | Managed Identity emphasis |

**Verdict:** Not drop-in replacements. Ours teaches **classic hub + Bicep + SDK**. Theirs is an **azd application template** for a hosted intelligent chat app.

---

## 1. Intent & audience

| | Ours | Azure sample |
|---|------|----------------|
| Goal | Learn classic hub infra + call model via SDK / flows | Deploy a working chat **web** product with optional RAG |
| Audience | Architects / learners of Foundry classic | Devs wanting Codespaces/`azd` zero-to-URL |
| Docs focus | Architecture Mermaid, day-2 ops | Solution overview, RAG, costs, security disclaimers |

---

## 2. Azure resources

| Resource | Ours | Azure sample |
|----------|:----:|:------------:|
| Classic AI Hub (`kind=Hub`) | Yes | Yes (template references AI Hub) |
| AI Project | Yes (hub project) | Yes |
| AI Services / models | Yes (`AIServices`, `gpt-5-mini`) | Yes (e.g. `gpt-4o-mini` + embeddings) |
| Storage / Key Vault / App Insights | Yes | Yes |
| Log Analytics | No | Optional |
| Azure AI Search (RAG) | No | Optional |
| Azure Container Apps | Optional (Gradio Dockerfile — bring your own host) | Yes |
| Azure Container Registry | No | Yes |
| Embedding model | No | Yes (RAG) |

---

## 3. Application layer

| Capability | Ours | Azure sample |
|------------|------|----------------|
| Chat UI | Optional Gradio (`app_gradio.py`) | Built-in web app |
| Conversation UX | Single-shot CLI or Gradio chat | Interactive hosted chat |
| RAG + citations | No | Yes |
| Prompt Flow sample | Yes (`chat-prompt-flow.py`) — retires 2027-04-20 | No |
| Tracing / App Insights in app | Infra attach only | Built into solution |
| Containerized deploy | Optional Dockerfile | First-class (`azd` + ACA) |
| Tests | No | `tests/` present |
| SDK | `azure-ai-projects==1.0.0b10` | Foundry / azd template stack |

---

## 4. Infrastructure & DX

| Capability | Ours | Azure sample |
|------------|------|----------------|
| IaC | Bicep + `environments/*.bicepparam` | Bicep + `azure.yaml` |
| Deploy | `deploy.sh` | `azd up` |
| Preview | `--what-if` | azd provisioning |
| Teardown | `remove.sh` / `destroy.sh` (granular) | `azd down` |
| Env separation | Explicit `dev`/`test`/`prod` | azd environments |
| Codespaces / Dev Container | No | Yes |
| CI scaffolding | Optional / planned | `.github` / `.azdo` |

**Where we win:** thin teachable Bicep, CAF env files, granular day-2 delete, classic SDK + Prompt Flow education.  
**Where they win:** one-command hosted app, Codespaces, RAG, pipelines.

---

## 5. Prompt Flow

Neither sample is “about” Prompt Flow as a product. Ours adds an **optional educational** flex flow (`prompt_flow/`) on the same AI Services account. Prompt Flow is **classic-hub-only** and **retires April 20, 2027** — not recommended for new development ([docs](https://learn.microsoft.com/en-us/azure/foundry-classic/concepts/prompt-flow)).

---

## 6. Scorecard

| Area | Parity | Notes |
|------|--------|-------|
| Classic hub + AI Services | High | Core overlap |
| Minimal SDK chat learning | Ours ahead | Simpler |
| Hosted chat web app | Theirs ahead | We offer optional Gradio only |
| RAG | Theirs | We have none |
| `azd` / Codespaces | Theirs | We use custom scripts |
| Multi-env CAF params | Ours | Theirs uses azd envs |
| Day-2 granular teardown | Ours | Theirs stack-level |
| Prompt Flow lab | Ours | Educational / EOL |

---

## 7. Recommended actions for this accelerator

**Keep (differentiate)**
- Classic hub/project + connection-string SDK
- Thin Bicep + `dev`/`test`/`prod`
- Day-2 scripts + Mermaid architecture
- Optional Prompt Flow (documented as retiring)
- Optional Gradio for local UI without full ACA template

**Borrow selectively**
1. Stronger cost + “not production” disclaimers
2. Optional `azd` wrapper later
3. Separate RAG module if needed (don’t bloat classic-chat)
4. Document Managed Identity as hardening vs ApiKey
5. Dev Container / light CI

**Do not blindly copy**
- Full ACA + ACR + RAG into classic-chat — changes learning goal and free-trial cost.

---

## Positioning

> **azure-ai-foundry-classic-chat** teaches the classic Foundry hub control plane and Python SDK (plus optional Prompt Flow / Gradio).  
> For a hosted chat UI with optional RAG and `azd up`, see [Azure-Samples/get-started-with-ai-chat](https://github.com/Azure-Samples/get-started-with-ai-chat).
