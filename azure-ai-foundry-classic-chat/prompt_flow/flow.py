"""Prompt Flow flex entry — classic hub learning sample.

Prompt Flow retires April 20, 2027. Prefer Foundry Agents for new work:
https://learn.microsoft.com/en-us/azure/foundry-classic/concepts/prompt-flow
"""

from __future__ import annotations

import os
from pathlib import Path

from promptflow.core import AzureOpenAIModelConfiguration, Prompty
from promptflow.tracing import trace

BASE_DIR = Path(__file__).resolve().parent


def _log(message: str) -> None:
    if os.environ.get("VERBOSE", "false").lower() == "true":
        print(message, flush=True)


class ChatFlow:
    def __init__(
        self,
        model_config: AzureOpenAIModelConfiguration,
        max_total_token: int = 4096,
    ) -> None:
        self.model_config = model_config
        self.max_total_token = max_total_token

    @trace
    def __call__(
        self,
        question: str = "Hey, can you help me with my taxes? I'm a freelancer.",
        chat_history: list | None = None,
    ) -> str:
        prompty = Prompty.load(
            source=BASE_DIR / "chat.prompty",
            model={"configuration": self.model_config},
        )

        history = list(chat_history or [])
        while history:
            token_count = prompty.estimate_token_count(
                question=question, chat_history=history
            )
            if token_count > self.max_total_token:
                history = history[1:]
                _log(f"Trimmed chat history to {len(history)} turns for token limit")
            else:
                break

        return prompty(question=question, chat_history=history)
