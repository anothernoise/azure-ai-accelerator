"""Load repo-root environment file for the active Azure environment (dev/prod)."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv


def repo_root() -> Path:
    # azure-ai-foundry-classic-chat/infra/scripts -> repo root
    return Path(__file__).resolve().parents[3]


def active_environment() -> str:
    return os.getenv("ENVIRONMENT", "dev").strip().lower()


def env_file_path(root: Path | None = None, environment: str | None = None) -> Path:
    root = root or repo_root()
    env = (environment or active_environment()).lower()
    return root / f".env.{env}"


def load_project_env(root: Path | None = None, environment: str | None = None) -> Path:
    """Load .env.{ENVIRONMENT}, falling back to .env if missing."""
    root = root or repo_root()
    env = (environment or active_environment()).lower()
    primary = root / f".env.{env}"
    fallback = root / ".env"

    if primary.exists():
        load_dotenv(primary, override=True)
        return primary
    if fallback.exists():
        load_dotenv(fallback, override=True)
        return fallback
    raise FileNotFoundError(
        f"No env file found. Expected {primary} or {fallback}. "
        f"Run: ENVIRONMENT={env} ./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh"
    )
