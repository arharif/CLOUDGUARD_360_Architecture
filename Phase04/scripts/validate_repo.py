#!/usr/bin/env python3
"""Static local preparation checks; does not access the cloud or GitHub."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
required = [
    'Dockerfile', '.dockerignore', '.github/workflows/01-ci.yml',
    '.github/workflows/02-release.yml', 'scripts/validate_repo.py',
]
missing = [p for p in required if not (root / p).is_file()]
dockerfile = (root / 'Dockerfile').read_text(encoding='utf-8')
errors = []
if missing:
    errors.append('Missing files: ' + ', '.join(missing))
if 'mcr.microsoft.com/azuredocs/azure-vote-front:v1' not in dockerfile:
    errors.append('Base image changed: manually verify the intended image before building.')
if errors:
    print('FAIL:', '\nFAIL: '.join(errors))
    sys.exit(1)
print('PASS: CloudGuard 360 Phase 04 repository layout and expected demo base image.')
