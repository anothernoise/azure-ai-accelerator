# Environment parameter files

| File | Purpose | Default RG pattern |
|------|---------|-------------------|
| `dev.bicepparam` | Learning, experiments, low cost | `rg-aialearn-dev-eus` |
| `test.bicepparam` | Staging / CI | `rg-aialearn-test-eus` |
| `prod.bicepparam` | Production workloads | `rg-aialearn-prod-eus` |

Deploy:

```bash
# from repo root
ENVIRONMENT=dev  ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh
ENVIRONMENT=prod ./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh   # prompts for confirmation
```

Each environment writes its own config file: `.env.dev`, `.env.prod` (repo root).
