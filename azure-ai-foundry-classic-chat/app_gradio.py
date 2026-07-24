#!/usr/bin/env python3
"""Optional Gradio UI for classic Foundry hub chat (same path as chat.py).

Usage (module directory):
  ENVIRONMENT=dev ../.venv/bin/python app_gradio.py

Docker:
  docker build -t classic-chat-gradio -f Dockerfile .
  docker run --rm -p 7860:7860 --env-file ../../.env.dev classic-chat-gradio
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(os.environ.get("CONFIG_ROOT", Path(__file__).resolve().parent.parent))
MODULE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(MODULE_DIR / "infra" / "scripts"))
from load_env import load_project_env  # noqa: E402

try:
    load_project_env(ROOT)
except FileNotFoundError:
    # Azure Container Apps injects env vars directly — no .env file needed
    if not os.getenv("AZURE_PROJECT_CONNECTION_STRING"):
        raise


import gradio as gr
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

SYSTEM_PROMPT = (
    "You are an AI assistant that speaks like a techno punk rocker from 2350. "
    "Be cool but not too cool. Ya dig?"
)


def _client() -> tuple[object, str]:
    conn = os.getenv("AZURE_PROJECT_CONNECTION_STRING")
    if not conn:
        raise ValueError(
            "AZURE_PROJECT_CONNECTION_STRING missing. Deploy first: "
            "./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev"
        )
    deployment = os.getenv("DEPLOYMENT_NAME", "gpt-5-mini")
    connection_name = os.getenv("AI_SERVICES_CONNECTION_NAME")
    project = AIProjectClient.from_connection_string(
        conn_str=conn,
        credential=DefaultAzureCredential(),
    )
    kwargs = {}
    if connection_name:
        kwargs["connection_name"] = connection_name
    chat = project.inference.get_chat_completions_client(**kwargs)
    return chat, deployment


_CHAT, _DEPLOYMENT = None, None


def get_chat():
    global _CHAT, _DEPLOYMENT
    if _CHAT is None:
        _CHAT, _DEPLOYMENT = _client()
    return _CHAT, _DEPLOYMENT


def respond(message: str, history: list) -> str:
    chat, deployment = get_chat()
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for turn in history or []:
        if isinstance(turn, dict) and turn.get("role") and turn.get("content"):
            messages.append(
                {"role": str(turn["role"]), "content": str(turn["content"])}
            )
    messages.append({"role": "user", "content": message})
    response = chat.complete(model=deployment, messages=messages)
    return response.choices[0].message.content


def build_ui() -> gr.Blocks:
    env = os.getenv("ENVIRONMENT_NAME", os.getenv("ENVIRONMENT", "dev"))
    project = os.getenv("PROJECT_NAME", "?")
    demo = gr.ChatInterface(
        fn=respond,
        title="Classic Foundry Chat",
        description=(
            f"Environment: **{env}** · Project: **{project}** · "
            f"Model: **{os.getenv('DEPLOYMENT_NAME', 'gpt-5-mini')}** — "
            "SDK path via hub project connection string (same as `chat.py`)."
        ),
    )
    return demo


if __name__ == "__main__":
    server_name = os.getenv("GRADIO_SERVER_NAME", "0.0.0.0")
    server_port = int(os.getenv("GRADIO_SERVER_PORT", "7860"))
    print(
        f"Starting Gradio on http://{server_name}:{server_port} "
        f"(env={os.getenv('ENVIRONMENT_NAME', 'dev')})",
        flush=True,
    )
    build_ui().launch(server_name=server_name, server_port=server_port)
