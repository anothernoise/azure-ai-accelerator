#!/usr/bin/env python3
"""Minimal classic Foundry Agents sample (hub project + azure-ai-projects).

Reuses the same Bicep stack as azure-ai-foundry-classic-chat (.env.dev).

Docs:
  https://learn.microsoft.com/en-us/azure/foundry-classic/how-to/develop/vs-code-agents

Usage:
  ENVIRONMENT=dev ../.venv/bin/python agent_chat.py
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "azure-ai-foundry-classic-chat" / "infra" / "scripts"))
from load_env import load_project_env  # noqa: E402

load_project_env(ROOT)

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

AGENT_NAME = os.getenv("AGENT_NAME", "aialearn-classic-agent")
QUESTION = os.getenv(
    "AGENT_QUESTION",
    "In one short paragraph, what is a classic Azure AI Foundry hub?",
)


def _message_text(msg) -> str:
    content = msg.content
    if isinstance(content, list) and content:
        part = content[0]
        if isinstance(part, dict):
            return str(part.get("text", {}).get("value") or part)
        text = getattr(part, "text", None)
        if text is not None:
            return str(getattr(text, "value", text))
        return str(part)
    return str(content)


def main() -> int:
    conn = os.getenv("AZURE_PROJECT_CONNECTION_STRING")
    deployment = os.getenv("DEPLOYMENT_NAME", "gpt-5-mini")
    env = os.getenv("ENVIRONMENT_NAME", os.getenv("ENVIRONMENT", "dev"))
    if not conn:
        raise ValueError(
            "AZURE_PROJECT_CONNECTION_STRING missing. Deploy classic-chat infra first:\n"
            "  ./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev"
        )

    print(f"Using environment: {env}", flush=True)
    print(f"Project connection loaded · model={deployment}", flush=True)
    print("Creating / reusing agent, then running a single thread…", flush=True)

    project = AIProjectClient.from_connection_string(
        conn_str=conn,
        credential=DefaultAzureCredential(),
    )

    agents = project.agents.list_agents().data
    agent = next((a for a in agents if a.name == AGENT_NAME), None)

    if agent is None:
        agent = project.agents.create_agent(
            model=deployment,
            name=AGENT_NAME,
            instructions=(
                "You are a concise Azure AI Foundry tutor. "
                "Answer briefly and accurately about classic hub projects."
            ),
        )
        print(f"Created agent id={agent.id} name={AGENT_NAME}", flush=True)
    else:
        print(f"Reusing agent id={agent.id} name={AGENT_NAME}", flush=True)

    thread = project.agents.create_thread()
    project.agents.create_message(
        thread_id=thread.id,
        role="user",
        content=QUESTION,
    )

    run = project.agents.create_and_process_run(
        thread_id=thread.id,
        agent_id=agent.id,
    )

    status = getattr(run, "status", None)
    status_val = getattr(status, "value", status)
    attempts = 0
    while str(status_val) in ("queued", "in_progress", "requires_action") and attempts < 60:
        time.sleep(1)
        run = project.agents.get_run(thread_id=thread.id, run_id=run.id)
        status = run.status
        status_val = getattr(status, "value", status)
        attempts += 1

    print(f"Run status: {status}", flush=True)
    if str(status_val).lower() not in ("completed", "runstatus.completed") and "COMPLETED" not in str(status):
        if "completed" not in str(status).lower():
            print(f"Run did not complete cleanly: {run}", file=sys.stderr)
            return 1

    messages = project.agents.list_messages(thread_id=thread.id).data
    for msg in messages:
        role = str(getattr(msg, "role", ""))
        if "agent" in role.lower() or "assistant" in role.lower():
            print(_message_text(msg))
            return 0

    print("No assistant message found.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
