# Legacy scripts (superseded by Bicep)

These `az` shell scripts were the Lesson 1 prototype for creating classic hub infra.

**Prefer:**

```bash
./azure-ai-foundry-legacy-chat/infra/scripts/deploy.sh --env dev
```

See [../../infra/README.md](../../infra/README.md) for Bicep layout, CAF naming, and dev/prod environments.

`azure.config.sh` loads repo-root `.env.{ENVIRONMENT}` (falls back to `.env`).
