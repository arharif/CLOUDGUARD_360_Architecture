#!/usr/bin/env python3
"""Validate vendored Azure Vote app, files and non-retired image source."""
from pathlib import Path
import ast,sys
root=Path(__file__).resolve().parent.parent
required=['Dockerfile','.dockerignore','.github/workflows/00-oidc-subject.yml','.github/workflows/01-ci.yml','.github/workflows/02-publish.yml','.github/workflows/03-deploy.yml','vendor/azure-vote/main.py','vendor/azure-vote/config_file.cfg','vendor/azure-vote/templates','vendor/azure-vote/static','docs/UPSTREAM_LICENSE.txt','docs/UPSTREAM_COMMIT.txt']
missing=[p for p in required if not (root/p).exists()]
if missing:sys.exit('STOP: Repository missing '+', '.join(missing))
try:ast.parse((root/'vendor/azure-vote/main.py').read_text())
except SyntaxError as e:sys.exit('STOP: Vendored Python source syntax invalid: '+str(e))
docker=(root/'Dockerfile').read_text()
if 'azuredocs/azure-vote-front' in docker:sys.exit('STOP: retired Microsoft image still referenced')
if 'COPY vendor/azure-vote/' not in docker:sys.exit('STOP: Dockerfile does not copy official vendored source')
print('PASS: official Azure Vote source, upstream licence and four workflows found')
