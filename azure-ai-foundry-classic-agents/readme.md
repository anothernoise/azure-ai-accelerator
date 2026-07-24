# azure-ai-foundry-classic-agents

Classic Foundry **Agents** sample on the same hub/project as [`azure-ai-foundry-classic-chat`](../azure-ai-foundry-classic-chat/).

Reuses Bicep-deployed infra and repo-root `.env.{environment}` — **do not** redeploy a second stack.

## Prerequisites

1. Deploy classic-chat infra:

```bash
./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev
```

2. Install deps:

```bash
pip install -r azure-ai-foundry-classic-agents/requirements.txt
# or reuse classic-chat requirements (same azure-ai-projects pin)
```

## Run

```bash
cd azure-ai-foundry-classic-agents
ENVIRONMENT=dev ../.venv/bin/python agent_chat.py

AGENT_QUESTION="What is a hub project?" \
  ENVIRONMENT=dev ../.venv/bin/python agent_chat.py
```

Creates (or reuses) an agent named `aialearn-classic-agent`, posts one user message, and prints the assistant reply.

## Docs

- [Create and manage Foundry agents in VS Code (classic)](https://learn.microsoft.com/en-us/azure/foundry-classic/how-to/develop/vs-code-agents)
- Classic chat module: [../azure-ai-foundry-classic-chat/readme.md](../azure-ai-foundry-classic-chat/readme.md)

## Layout

| Path | Role |
|------|------|
| `agent_chat.py` | Create agent → thread → run → print reply |
| `requirements.txt` | Same SDK pin as classic-chat |

## Notes

- Agents on **hub projects** are a classic path; new Foundry Agent Service (GA) is a separate module later.
- Clean up agents in the portal or via `project.agents.delete_agent(agent_id)` if you create many.
