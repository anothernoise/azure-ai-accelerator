#!/usr/bin/env python3
"""Write Bicep deployment outputs into .env.{environment}."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


KEYS = {
    "ENVIRONMENT_NAME": "environmentName",
    "AZURE_PROJECT_CONNECTION_STRING": "projectConnectionString",
    "RESOURCE_GROUP_NAME": "resourceGroupName",
    "LOCATION": "location",
    "COG_SERVICES_ACCOUNT_NAME": "aiServicesName",
    "HUB_NAME": "hubName",
    "PROJECT_NAME": "projectName",
    "AI_SERVICES_CONNECTION_NAME": "aiServicesConnectionName",
    "DEPLOYMENT_NAME": "deploymentName",
}


def az_outputs(resource_group: str, deployment: str) -> dict:
    raw = subprocess.check_output(
        [
            "az",
            "deployment",
            "group",
            "show",
            "-g",
            resource_group,
            "-n",
            deployment,
            "--query",
            "properties.outputs",
            "-o",
            "json",
        ],
        text=True,
    )
    data = json.loads(raw)
    return {k: v.get("value") for k, v in data.items()}


def build_connection_string_from_discovery(
    resource_group: str, project_name: str
) -> str:
    """Build classic connection string from live project discovery_url."""
    discovery = subprocess.check_output(
        [
            "az",
            "ml",
            "workspace",
            "show",
            "-g",
            resource_group,
            "-n",
            project_name,
            "--query",
            "discovery_url",
            "-o",
            "tsv",
        ],
        text=True,
    ).strip()

    if not discovery or discovery == "null":
        raise RuntimeError(f"Could not read discovery_url for project '{project_name}'")

    hostname = discovery.removeprefix("https://").removeprefix("http://")
    hostname = hostname.removesuffix("/discovery").removesuffix("/")

    subscription_id = subprocess.check_output(
        ["az", "account", "show", "--query", "id", "-o", "tsv"],
        text=True,
    ).strip()

    return f"{hostname};{subscription_id};{resource_group};{project_name}"


def upsert_env(path: Path, values: dict[str, str], environment: str) -> None:
    text = path.read_text() if path.exists() else ""
    values.setdefault("ENVIRONMENT_NAME", environment)

    for key, value in values.items():
        if value is None or value == "":
            continue
        line = f'{key}="{value}"'
        pattern = re.compile(rf"^{re.escape(key)}=.*$", re.M)
        if pattern.search(text):
            text = pattern.sub(line, text, count=1)
        else:
            if text and not text.endswith("\n"):
                text += "\n"
            text += line + "\n"

    defaults = {
        "COG_SERVICES_KIND": "AIServices",
        "COG_SERVICES_SKU": "S0",
        "MODEL_NAME": values.get("DEPLOYMENT_NAME", "gpt-5-mini"),
        "MODEL_VERSION": "2025-08-07",
        "MODEL_FORMAT": "OpenAI",
        "DEPLOYMENT_SKU_NAME": "GlobalStandard",
        "DEPLOYMENT_SKU_CAPACITY": "1",
    }
    for key, value in defaults.items():
        pattern = re.compile(rf"^{re.escape(key)}=.*$", re.M)
        line = f'{key}="{value}"'
        if not pattern.search(text):
            if text and not text.endswith("\n"):
                text += "\n"
            text += line + "\n"

    path.write_text(text)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--resource-group", required=True)
    parser.add_argument("--deployment", required=True)
    parser.add_argument("--environment", required=True)
    parser.add_argument("--env-file", required=True)
    parser.add_argument(
        "--live-connection",
        action="store_true",
        help="Rebuild AZURE_PROJECT_CONNECTION_STRING from live project discovery_url",
    )
    args = parser.parse_args()

    outputs = az_outputs(args.resource_group, args.deployment)
    values = {env_key: outputs.get(out_key) for env_key, out_key in KEYS.items()}

    if args.live_connection:
        project_name = values.get("PROJECT_NAME") or outputs.get("projectName")
        if not project_name:
            print("Missing project name in deployment outputs; cannot use --live-connection", file=sys.stderr)
            return 1
        values["AZURE_PROJECT_CONNECTION_STRING"] = build_connection_string_from_discovery(
            args.resource_group, project_name
        )

    env_path = Path(args.env_file)
    upsert_env(env_path, values, args.environment.lower())

    print(f"Updated {env_path}")
    for k, v in values.items():
        if v:
            print(f"  {k}={v}")
    print(f"  ENVIRONMENT_NAME={args.environment.lower()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
