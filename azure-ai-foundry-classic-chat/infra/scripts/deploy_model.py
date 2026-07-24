#!/usr/bin/env python3
"""Manage model deployments on an existing AI Services account (day-2 ops)."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys

from load_env import load_project_env


def confirm_prod(env_name: str, message: str) -> bool:
    if env_name != "prod":
        return True
    reply = input(f"{message} in PROD? [y/N] ")
    return reply.lower() in ("y", "yes")


def az(*args: str) -> None:
    subprocess.check_call(["az", *args])


def list_deployment_names(rg: str, account: str) -> list[str]:
    raw = subprocess.check_output(
        [
            "az", "cognitiveservices", "account", "deployment", "list",
            "-g", rg, "-n", account, "--query", "[].name", "-o", "tsv",
        ],
        text=True,
    )
    return [line.strip() for line in raw.splitlines() if line.strip()]


def main() -> int:
    load_project_env()

    parser = argparse.ArgumentParser(
        description="Manage AI model deployments",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Commands:
  create       Create deployment from .env settings
  list         List all deployments
  show         Show DEPLOYMENT_NAME details
  update       Update sku/capacity for DEPLOYMENT_NAME
  delete       Delete DEPLOYMENT_NAME (alias: remove)
  delete-all   Delete all deployments (alias: remove-all)
""",
    )
    parser.add_argument(
        "action",
        choices=[
            "create", "list", "show", "update",
            "delete", "remove",
            "delete-all", "remove-all",
        ],
        nargs="?",
        default="create",
    )
    args = parser.parse_args()
    action = args.action.replace("remove", "delete")

    rg = os.environ["RESOURCE_GROUP_NAME"]
    account = os.environ["COG_SERVICES_ACCOUNT_NAME"]
    deployment = os.environ.get("DEPLOYMENT_NAME", "gpt-5-mini")
    model = os.environ.get("MODEL_NAME", deployment)
    version = os.environ.get("MODEL_VERSION", "2025-08-07")
    fmt = os.environ.get("MODEL_FORMAT", "OpenAI")
    sku = os.environ.get("DEPLOYMENT_SKU_NAME", "GlobalStandard")
    capacity = os.environ.get("DEPLOYMENT_SKU_CAPACITY", "1")
    env_name = os.environ.get("ENVIRONMENT_NAME", os.getenv("ENVIRONMENT", "dev"))

    print(f"Using ENVIRONMENT={env_name}  RG={rg}  account={account}")

    if action == "list":
        az("cognitiveservices", "account", "deployment", "list", "-g", rg, "-n", account, "-o", "table")
        return 0

    if action == "show":
        az(
            "cognitiveservices", "account", "deployment", "show",
            "-g", rg, "-n", account, "--deployment-name", deployment, "-o", "table",
        )
        return 0

    if action == "update":
        print(f"Updating {deployment}: sku={sku} capacity={capacity}")
        az(
            "cognitiveservices", "account", "deployment", "update",
            "-g", rg, "-n", account,
            "--deployment-name", deployment,
            "--sku-name", sku, "--sku-capacity", capacity,
            "-o", "table",
        )
        return 0

    if action == "delete":
        if not confirm_prod(env_name, f"Delete deployment '{deployment}'"):
            print("Cancelled.")
            return 0
        az(
            "cognitiveservices", "account", "deployment", "delete",
            "-g", rg, "-n", account, "--deployment-name", deployment, "--yes",
        )
        return 0

    if action == "delete-all":
        names = list_deployment_names(rg, account)
        if not names:
            print("No deployments found.")
            return 0
        print("Will delete:")
        for name in names:
            print(f"  - {name}")
        if not confirm_prod(env_name, f"Delete ALL {len(names)} deployment(s)"):
            print("Cancelled.")
            return 0
        reply = input(f"Delete ALL {len(names)} deployment(s)? [y/N] ")
        if reply.lower() not in ("y", "yes"):
            print("Cancelled.")
            return 0
        for name in names:
            print(f"Deleting '{name}'...")
            az(
                "cognitiveservices", "account", "deployment", "delete",
                "-g", rg, "-n", account, "--deployment-name", name, "--yes",
            )
        print("All deployments deleted.")
        return 0

    # create
    az(
        "cognitiveservices", "account", "deployment", "create",
        "-g", rg, "-n", account,
        "--deployment-name", deployment,
        "--model-name", model,
        "--model-version", version,
        "--model-format", fmt,
        "--sku-name", sku, "--sku-capacity", capacity,
        "-o", "table",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
