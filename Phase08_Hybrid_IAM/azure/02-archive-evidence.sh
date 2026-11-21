#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/evidence"
python3 - "$ROOT" <<'PY'
import pathlib,zipfile,datetime,sys
root=pathlib.Path(sys.argv[1]); out=root/'evidence'/('CG360_Phase08_Evidence_'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d_%H%M%S')+'.zip')
allowed=[root/'evidence'/'ad',root/'evidence'/'cloud',root/'evidence'/'reconciliation']
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 for d in allowed:
  if not d.exists(): continue
  for f in d.rglob('*'):
   if f.is_file() and f.suffix.lower() in {'.json','.csv','.md','.txt'}: z.write(f,f.relative_to(root))
print('Evidence:',out)
print('Review files before sharing: object IDs and user identifiers may be present.')
PY
