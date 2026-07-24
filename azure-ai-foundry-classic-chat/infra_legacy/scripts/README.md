# Legacy scripts (superseded by Bicep)

These `az` shell scripts were the prototype for creating classic hub infra.

**Canonical location:** `azure-ai-foundry-classic-chat/infra_legacy/scripts/`  
(Do not nest under `infra/`.)

**Prefer:**

```bash
./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev
```

See [../infra/README.md](../infra/README.md) for Bicep layout, CAF naming, and day-2 ops.

`azure.config.sh` loads repo-root `.env.{ENVIRONMENT}` (falls back to `.env`).
