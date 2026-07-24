# Optional Gradio UI for classic Foundry hub chat
FROM python:3.12-slim

WORKDIR /app

# Azure Identity in containers typically uses managed identity or
# AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_CLIENT_SECRET, or mount Azure CLI creds for local demos.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt requirements-ui.txt ./
RUN pip install --no-cache-dir -r requirements-ui.txt

COPY chat.py app_gradio.py ./
COPY infra/scripts/load_env.py infra/scripts/

ENV PYTHONUNBUFFERED=1
ENV GRADIO_SERVER_NAME=0.0.0.0
ENV GRADIO_SERVER_PORT=7860
ENV ENVIRONMENT=dev

EXPOSE 7860

CMD ["python", "app_gradio.py"]
