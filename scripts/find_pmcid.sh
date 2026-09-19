#!/bin/bash
# Find PMCID for a DOI via Europe PMC REST (works with curl).
# Usage: find_pmcid.sh <doi>   -> prints PMCID or empty
DOI="$1"
curl -s --ssl-no-revoke --max-time 30 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0" \
  "https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:%22${DOI}%22&format=json&resultType=core" \
| "${WB_PY:-C:/Users/AcTor/.workbuddy/binaries/python/envs/default/Scripts/python.exe}" -c "
import json,sys
try:
    d=json.load(sys.stdin)
    rs=d.get('resultList',{}).get('result',[])
    for r in rs:
        p=r.get('pmcid','')
        if p:
            print(p); break
except Exception:
    pass
"
