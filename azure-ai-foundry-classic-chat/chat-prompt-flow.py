#!/usr/bin/env python3
"""Run a local Prompt Flow chat against the classic Foundry AI Services account.

Educational / classic-hub sample only.

Prompt Flow (Foundry classic + AML) retires **April 20, 2027** and is not
recommended for new development. Prefer Microsoft Agent Framework / Foundry
Agents for new work:
https://learn.microsoft.com/en-us/azure/foundry-classic/concepts/prompt-flow

Usage (from repo root, after Bicep deploy):

  pip install -r azure-ai-foundry-classic-chat/requirements.txt
  ENVIRONMENT=dev ../.venv/bin/python azure-ai-foundry-classic-chat/chat-prompt-flow.py

Or from this module directory:

  ENVIRONMENT=dev ../.venv/bin/python chat-prompt-flow.py
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULE_DIR = Path(__file__).resolve().parent
CONN_NAME = "aialearn_aoai_connection"

sys.path.insert(0, str(MODULE_DIR))
sys.path.insert(0, str(ROOT / "azure-ai-foundry-classic-chat" / "infra" / "scripts"))
from load_env import load_project_env  # noqa: E402

load_project_env(ROOT)


def _az(*args: str) -> str:
    return subprocess.check_output(["az", *args], text=True).strip()


def ensure_promptflow_connection(rg: str, account: str) -> str:
    """Create/update a local Prompt Flow AzureOpenAIConnection from Azure CLI keys."""
    from promptflow.client import PFClient
    from promptflow.connections import AzureOpenAIConnection

    endpoint = _az(
        "cognitiveservices",
        "account",
        "show",
        "-g",
        rg,
        "-n",
        account,
        "--query",
        "properties.endpoint",
        "-o",
        "tsv",
    )
    api_key = _az(
        "cognitiveservices",
        "account",
        "keys",
        "list",
        "-g",
        rg,
        "-n",
        account,
        "--query",
        "key1",
        "-o",
        "tsv",
    )
    if not endpoint or not api_key:
        raise RuntimeError(
            f"Could not read endpoint/key for {account} in {rg}. "
            "Check az login and RESOURCE_GROUP_NAME / COG_SERVICES_ACCOUNT_NAME."
        )

    pf = PFClient()
    connection = AzureOpenAIConnection(
        name=CONN_NAME,
        api_key=api_key,
        api_base=endpoint,
        api_type="azure",
        api_version="2024-10-21",
    )
    pf.connections.create_or_update(connection)
    return endpoint


def main() -> int:
    environment_name = os.getenv("ENVIRONMENT_NAME", os.getenv("ENVIRONMENT", "dev"))
    rg = os.environ.get("RESOURCE_GROUP_NAME")
    account = os.environ.get("COG_SERVICES_ACCOUNT_NAME")
    deployment = os.getenv("DEPLOYMENT_NAME", "gpt-5-mini")
    question = os.getenv(
        "PROMPT_FLOW_QUESTION",
        "Hey, can you help me with my taxes? I'm a freelancer.",
    )

    if not rg or not account:
        raise ValueError(
            "RESOURCE_GROUP_NAME and COG_SERVICES_ACCOUNT_NAME required. "
            f"Run: ENVIRONMENT={environment_name} "
            "./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh"
        )

    print(
        "NOTE: Prompt Flow retires 2027-04-20 — educational classic-hub sample only.",
        flush=True,
    )
    print(f"Using environment: {environment_name}", flush=True)
    print(f"AI Services: {account}  model: {deployment}", flush=True)
    print("Ensuring local Prompt Flow connection via az CLI…", flush=True)

    endpoint = ensure_promptflow_connection(rg, account)
    print(f"Connection '{CONN_NAME}' → {endpoint}", flush=True)

    from promptflow.core import AzureOpenAIModelConfiguration

    from prompt_flow.flow import ChatFlow

    config = AzureOpenAIModelConfiguration(
        connection=CONN_NAME,
        azure_deployment=deployment,
    )
    flow = ChatFlow(config)

    print("Running Prompt Flow ChatFlow (may take 15–30s)…", flush=True)
    answer = flow(question=question, chat_history=[])
    print(answer)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ModuleNotFoundError as exc:
        if "promptflow" in str(exc).lower() or "prompt_flow" in str(exc):
            print(
                "Missing Prompt Flow packages. Install:\n"
                "  pip install -r azure-ai-foundry-classic-chat/requirements.txt",
                file=sys.stderr,
            )
        raise
