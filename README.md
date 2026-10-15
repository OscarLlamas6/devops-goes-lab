# tramites-platform

Public service to check the status of a citizen procedure (trámite), deployed on Cloud Run with a
supply-chain-secured pipeline (Binary Authorization). Technical challenge for DevOps Senior.

> Work in progress: this README is a skeleton. The final version (diagram, step-by-step
> deployment, decisions, costs, destruction, pending work) arrives in phase 6.

## Secret protection

Defense in layers (decision D13):

1. `.gitignore` keeps `.env`, `*.tfvars`, `*.tfstate*` and key files out of Git.
2. pre-commit hooks (gitleaks, private-key detection, file-name blocking, GCP key content).
3. The same `.pre-commit-config.yaml` runs in CI (job `security`), which blocks the merge.
4. gitleaks scans the full history in CI.

Install the hooks (one command, idempotent):

```bash
./scripts/setup-dev.sh
```

Prove the barrier works (fake secrets must be blocked, a legitimate commit must pass):

```bash
./scripts/test-secret-hooks.sh
```

If a secret reaches GitHub: **rotate it first** (it is already compromised), then clean the
history with `git filter-repo` and notify. Rewriting history alone is not enough.

## AI usage

I used Claude Code (Anthropic) to generate code, Terraform and documentation under my direction;
I reviewed it and can explain every part. AI-assisted commits keep the `Co-Authored-By` trailer.
