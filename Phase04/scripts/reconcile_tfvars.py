#!/usr/bin/env python3
"""Reconcile Phase 03 frontend_image in HCL tfvars, preserving everything else."""
from pathlib import Path
import re,sys
if len(sys.argv)!=3:sys.exit('Usage: reconcile_tfvars.py PATH IMAGE')
p=Path(sys.argv[1]); image=sys.argv[2]
if not re.fullmatch(r'ghcr\.io/[a-z0-9_.-]+/cloudguard360-vote:[0-9a-f]{40}',image):
    sys.exit('STOP: only a full SHA-tagged GHCR image allowed')
s=p.read_text()
pat=r'(?m)^\s*frontend_image\s*=\s*"[^"\n]*"\s*(?:#.*)?$'
if len(re.findall(pat,s))!=1:sys.exit('STOP: frontend_image assignment missing or ambiguous; edit manually')
s2=re.sub(pat, 'frontend_image = "'+image+'"',s)
p.write_text(s2)
print('PASS: Phase 03 terraform.tfvars frontend_image updated. No Terraform apply performed.')
