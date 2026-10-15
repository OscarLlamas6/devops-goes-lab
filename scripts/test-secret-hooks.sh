#!/usr/bin/env bash
# Proves the secret barrier works: in a throwaway repo it tries to commit fake secrets
# (must be blocked) and a legitimate change (must pass). Exits non-zero on any surprise.
# Fake secrets are built at runtime from fragments so THIS file never trips gitleaks.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

rand() { python3 -I -c 'import secrets,string,sys;print("".join(secrets.choice(string.ascii_letters+string.digits) for _ in range(int(sys.argv[1]))))' "$1"; }

cd "$WORK"
git init -q -b main
git config user.name "Hook Test"
git config user.email "hook-test@example.com"
git config commit.gpgsign false
mkdir scripts
cp "$ROOT/.pre-commit-config.yaml" "$ROOT/.gitleaks.toml" .
cp "$ROOT/scripts/check-branch-name.sh" scripts/
echo "Installing hooks in temp repo $WORK ..."
pre-commit install --install-hooks >/dev/null 2>&1

# Fake secrets, assembled from fragments
pem_head="-----BEGIN RSA ""PRIVATE KEY-----"
pem_tail="-----END RSA ""PRIVATE KEY-----"
pem_body="$(rand 64)$(rand 64)"
sa_type='"ty''pe": "service_''account"'
sa_kid='"private_k''ey_id": "'"$(rand 40)"'"'
sa_key='"private_k''ey": "'"$pem_head"'\n'"$pem_body"'\n'"$pem_tail"'\n"'
gcp_key="AI""za$(rand 35)"

RESULTS=""
FAILURES=0
LOG="$WORK/last.log"

# expect_block|expect_pass  <case name>  <commit message>  (files already written)
attempt() {
  local expected="$1" name="$2" msg="$3" got
  git add -f -A >/dev/null 2>&1
  if git commit -q -m "$msg" >"$LOG" 2>&1; then got="pass"; else got="block"; fi
  if [ "$got" != "$expected" ]; then
    FAILURES=$((FAILURES + 1))
    echo "---- unexpected result for: $name ----"; cat "$LOG"; echo "--------------------------------------"
  fi
  RESULTS="${RESULTS}$(printf '%-40s %-10s %-10s %s' "$name" "$expected" "$got" "$([ "$got" = "$expected" ] && echo OK || echo MISMATCH)")"$'\n'
  # Leave the repo clean for the next case
  if [ "$got" = "block" ]; then git reset -q >/dev/null 2>&1 || true; fi
  git clean -fdxq -e .pre-commit-config.yaml -e .gitleaks.toml -e scripts >/dev/null 2>&1 || true
}

git checkout -q -b feature/DEVOPS-00-hooks-test

# Legitimate case first: it also creates the first commit
printf 'PORT=8080\nAPI_KEY=changeme\n' > .env.example
attempt pass "legit: .env.example + feat commit" "feat: add env example"
# The feature branch was created on an unborn repo, so main must be recreated for the main-branch case
git branch -q main

# Blocked by content or by name
printf '%s\n%s\n%s\n' "$pem_head" "$pem_body" "$pem_tail" > id_dummy.txt
attempt block "PEM private key" "feat: add key"

printf '{\n  %s,\n  %s,\n  %s\n}\n' "$sa_type" "$sa_kid" "$sa_key" > notes.json
attempt block "GCP service account JSON" "feat: add notes"

printf 'key = "%s"\n' "$gcp_key" > settings.txt
attempt block "Google API key (AIza...)" "feat: add settings"

printf 'API_KEY=%s\n' "$(rand 32)" > .env
attempt block ".env with a value" "feat: add env"

printf '{}\n' > terraform.tfstate
attempt block "terraform.tfstate" "feat: add state"

printf 'hello\n' > hello.txt
attempt block "non-conventional commit message" "added some stuff"

git checkout -q -b random-branch
printf 'hello\n' > hello.txt
attempt block "invalid branch name" "feat: add hello"
git checkout -q feature/DEVOPS-00-hooks-test
git branch -q -D random-branch

git checkout -q main
printf 'hello\n' > hello.txt
attempt block "direct commit to main" "feat: add hello"
git checkout -q feature/DEVOPS-00-hooks-test

echo
printf '%-40s %-10s %-10s %s\n' "CASE" "EXPECTED" "GOT" "RESULT"
printf '%s' "$RESULTS"
echo
if [ "$FAILURES" -ne 0 ]; then
  echo "❌ $FAILURES case(s) did not behave as expected."
  exit 1
fi
echo "✅ The barrier blocks every secret case and allows the legitimate one."
