# tramites-platform

Public service to check the status of a citizen procedure (trámite): the citizen enters a number
and sees its status. It runs on Cloud Run and is delivered through a pipeline that only deploys
images attested by the pipeline itself (Binary Authorization).

> Work in progress: the full documentation (architecture diagram, step-by-step deployment,
> decisions, costs, destruction) will be completed as the platform is built.

## API

Single file, standard library only: [app/main.go](app/main.go).

| Endpoint | Response |
|---|---|
| `GET /health` | `200 {"status":"ok","version":"<version>","secret_configured":true}` |
| `GET /v1/tramites/{numero}` | `200 {"numero":"...","estado":"..."}`, or `404` if it does not exist |

Configuration is only through environment variables: `PORT` (default `8080`) and `API_KEY`
(required: the service refuses to start without it and never prints its value).

Run it locally:

```bash
cd app && go test -race ./...
docker build -t tramites-api:local --build-arg APP_VERSION=local app
docker run --rm -e API_KEY=local-test -p 8080:8080 tramites-api:local
curl -s localhost:8080/health
curl -s localhost:8080/v1/tramites/TRM-000001
```

## Secret protection

Defense in layers, because any single layer can be skipped:

1. `.gitignore` keeps `.env`, `*.tfvars`, `*.tfstate*` and key files out of Git.
2. pre-commit hooks: gitleaks, private-key detection, blocking sensitive file names and GCP
   service account key content.
3. The same `.pre-commit-config.yaml` runs in CI (job `security`), which blocks the merge. A local
   hook can be skipped with `--no-verify` or never installed; CI cannot.
4. gitleaks scans the full git history in CI.

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

## Workflow

Trunk-based. Branches are `feature/DEVOPS-NN-description`, `fix/DEVOPS-NN` or
`hotfix/DEVOPS-NN`, commits follow Conventional Commits, and everything enters `main` through a
pull request with green checks.

## AI usage

I used Claude Code (Anthropic) to generate code, Terraform and documentation under my direction;
I reviewed it and can explain every part. AI-assisted commits keep the `Co-Authored-By` trailer.
