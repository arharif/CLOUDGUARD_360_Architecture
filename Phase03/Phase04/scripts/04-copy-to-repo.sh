#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then echo 'Usage: bash scripts/04-copy-to-repo.sh /full/path/to/my-github-clone'; exit 2; fi
TARGET="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -d "$TARGET/.git" ]]; then echo 'ERROR: destination must already be a cloned Git repository'; exit 2; fi
mkdir -p "$TARGET/.github/workflows" "$TARGET/scripts" "$TARGET/docs"
cp "$ROOT/Dockerfile" "$ROOT/.dockerignore" "$ROOT/.gitignore" "$TARGET/"
cp "$ROOT/.github/workflows/01-ci.yml" "$ROOT/.github/workflows/02-release.yml" "$TARGET/.github/workflows/"
cp "$ROOT/scripts/validate_repo.py" "$TARGET/scripts/"
cp "$ROOT/docs/release-runbook.md" "$TARGET/docs/"
python3 "$TARGET/scripts/validate_repo.py"
echo 'Copied essential CI/CD files; existing app files were not removed.'
