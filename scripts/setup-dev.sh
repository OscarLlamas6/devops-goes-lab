#!/usr/bin/env bash
# Installs/validates pre-commit and gitleaks, registers the git hooks and scans the repo.
# Idempotent. Usage: ./scripts/setup-dev.sh [--yes]   (--yes accepts every install prompt)
set -euo pipefail

GITLEAKS_VERSION="8.30.1"
GITLEAKS_SHA256_LINUX_X64="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"
GITLEAKS_SHA256_LINUX_ARM64="e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080"

YES=0
if [ "${1:-}" = "--yes" ]; then YES=1; fi

SUMMARY=""
FAILED=0
ok()   { SUMMARY="${SUMMARY}  ✅ $1"$'\n'; }
fail() { SUMMARY="${SUMMARY}  ❌ $1"$'\n'; FAILED=1; }

confirm() {
  if [ "$YES" -eq 1 ]; then return 0; fi
  local answer
  read -r -p "$1 [y/N] " answer || return 1
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

finish() {
  echo
  echo "Summary:"
  printf '%s' "$SUMMARY"
  echo
  if [ "$FAILED" -eq 0 ]; then
    echo "All good. Next: ./scripts/test-secret-hooks.sh"
  else
    echo "Some steps failed. Fix them and re-run ./scripts/setup-dev.sh"
    exit 1
  fi
}

install_gitleaks_linux() {
  local arch sha url tmp
  case "$(uname -m)" in
    x86_64|amd64)  arch="x64";   sha="$GITLEAKS_SHA256_LINUX_X64" ;;
    aarch64|arm64) arch="arm64"; sha="$GITLEAKS_SHA256_LINUX_ARM64" ;;
    *) echo "Unsupported architecture: $(uname -m)"; return 1 ;;
  esac
  url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${arch}.tar.gz"
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/gitleaks.tar.gz"
  # The expected hash is pinned in this script, so a tampered download is rejected.
  if ! echo "${sha}  ${tmp}/gitleaks.tar.gz" | sha256sum -c - >/dev/null 2>&1; then
    echo "Checksum mismatch for the gitleaks download. Aborting."
    rm -rf "$tmp"
    return 1
  fi
  tar -xzf "$tmp/gitleaks.tar.gz" -C "$tmp" gitleaks
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$tmp/gitleaks" "$HOME/.local/bin/gitleaks"
  rm -rf "$tmp"
  export PATH="$HOME/.local/bin:$PATH"
}

# 1. Must run at the root of a git repository
if [ "$(git rev-parse --show-toplevel 2>/dev/null || true)" != "$(pwd -P)" ]; then
  echo "Run this script from the root of the git repository." >&2
  exit 1
fi
ok "running at the repository root"

# 2. pre-commit
if ! command -v pre-commit >/dev/null 2>&1; then
  if ! command -v python3 >/dev/null 2>&1; then
    fail "python3 not found (required for pre-commit)"; finish
  fi
  if command -v pipx >/dev/null 2>&1; then
    if confirm "pre-commit not found. Install it with pipx?"; then
      pipx install pre-commit
    fi
  else
    echo "pre-commit not found and pipx is missing."
    echo "  Linux (Debian/Ubuntu): sudo apt install pipx && pipx ensurepath && pipx install pre-commit"
    echo "  macOS:                 brew install pre-commit"
  fi
fi
if command -v pre-commit >/dev/null 2>&1; then
  ok "pre-commit: $(pre-commit --version)"
else
  fail "pre-commit not installed"; finish
fi

# 3. gitleaks
if ! command -v gitleaks >/dev/null 2>&1 && [ -x "$HOME/.local/bin/gitleaks" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
if ! command -v gitleaks >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin)
      echo "gitleaks not found. Install it with: brew install gitleaks"
      if command -v brew >/dev/null 2>&1 && confirm "Run 'brew install gitleaks' now?"; then
        brew install gitleaks
      fi
      ;;
    Linux)
      echo "gitleaks not found. It will be downloaded from the official release v${GITLEAKS_VERSION}"
      echo "and verified against a pinned SHA-256, then installed to ~/.local/bin (no sudo)."
      if confirm "Install gitleaks v${GITLEAKS_VERSION} now?"; then
        install_gitleaks_linux || true
      fi
      ;;
    *) echo "Unsupported OS for automatic install: install gitleaks manually." ;;
  esac
fi
if command -v gitleaks >/dev/null 2>&1; then
  ok "gitleaks: $(gitleaks version)"
else
  fail "gitleaks not installed"; finish
fi

# 4. core.hooksPath: never overwrite it. pre-commit refuses to install if it is set.
hooks_path="$(git config --get core.hooksPath || true)"
if [ -n "$hooks_path" ]; then
  fail "core.hooksPath is set to '$hooks_path'; not modifying it. Unset it or wire the hooks there manually."
  finish
fi

# 5. Register pre-commit, commit-msg and pre-push (default_install_hook_types)
if pre-commit install --install-hooks; then
  ok "git hooks registered (pre-commit, commit-msg, pre-push)"
else
  fail "pre-commit install failed"
fi

# 6. Scan: history (if any), working tree, and every tracked file with all hooks
if git rev-parse -q --verify HEAD >/dev/null 2>&1; then
  if gitleaks git --redact; then ok "gitleaks: git history clean"; else fail "gitleaks found secrets in the history"; fi
else
  ok "gitleaks: no commits yet, history scan skipped"
fi

if gitleaks dir . --redact; then ok "gitleaks: working tree clean"; else fail "gitleaks found secrets in the working tree"; fi

if [ -n "$(git ls-files)" ]; then
  # On main the no-commit-to-branch hook would fail by design; this run validates content only.
  if [ "$(git symbolic-ref --short -q HEAD || true)" = "main" ]; then export SKIP="${SKIP:+$SKIP,}no-commit-to-branch"; fi
  if pre-commit run --all-files; then ok "pre-commit: all tracked files pass"; else fail "pre-commit run --all-files reported problems"; fi
else
  ok "pre-commit --all-files skipped (no tracked files yet; hooks run on the first commit)"
fi

finish
