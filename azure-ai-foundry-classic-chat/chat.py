import os
import sys
from pathlib import Path

# Load .env.{ENVIRONMENT} from repo root (see azure-ai-foundry-classic-chat/infra/scripts/load_env.py)
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "azure-ai-foundry-classic-chat" / "infra" / "scripts"))
from load_env import load_project_env  # noqa: E402

load_project_env(ROOT)

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

project_connection_string = os.getenv("AZURE_PROJECT_CONNECTION_STRING")
deployment_name = os.getenv("DEPLOYMENT_NAME", "gpt-5-mini")
connection_name = os.getenv("AI_SERVICES_CONNECTION_NAME")
environment_name = os.getenv("ENVIRONMENT_NAME", os.getenv("ENVIRONMENT", "dev"))

if not project_connection_string:
    raise ValueError(
        "AZURE_PROJECT_CONNECTION_STRING is not set. "
        f"Run: ENVIRONMENT={environment_name} ./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh"
    )

print(f"Using environment: {environment_name}")
print(f"Project: {os.getenv('PROJECT_NAME', '?')}  model: {deployment_name}", flush=True)
print("Calling model (may take 15–30s)…", flush=True)

project = AIProjectClient.from_connection_string(
    conn_str=project_connection_string,
    credential=DefaultAzureCredential(),
)

chat_kwargs = {}
if connection_name:
    chat_kwargs["connection_name"] = connection_name

chat = project.inference.get_chat_completions_client(**chat_kwargs)
response = chat.complete(
    model=deployment_name,
    messages=[
        {
            "role": "system",
            "content": (
                "You are an AI assistant that speaks like a techno punk rocker "
                "from 2350. Be cool but not too cool. Ya dig?"
            ),
        },
        {
            "role": "user",
            "content": "Hey, can you help me with my taxes? I'm a freelancer.",
        },
    ],
)

print(response.choices[0].message.content)
