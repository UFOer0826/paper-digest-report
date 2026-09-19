#!/bin/bash
# Download OA PDF for a DOI via Unpaywall using curl; tries all OA locations.
# Usage: fetch_pdf.sh <doi> <out.pdf>
DOI="$1"
OUT="$2"
PY="${WB_PY:-C:/Users/AcTor/.workbuddy/binaries/python/envs/default/Scripts/python.exe}"
TMP="$(mktemp)"
curl -s --max-time 30 "https://api.unpaywall.org/v2/${DOI}?email=workbuddy.research@gmail.com" -o "$TMP"
URLS=$("$PY" -c "
import json,sys
try:
    d=json.load(open(r'''$TMP''',encoding='utf-8'))
except Exception:
    sys.exit()
locs=[]
b=d.get('best_oa_location')
if b: locs.append(b)
locs+=d.get('oa_locations',[])
urls=[]
for l in locs:
    for k in ('url_for_pdf','url'):
        u=l.get(k)
        if u and u not in urls: urls.append(u)
def score(u):
    s=0
    if 'pdf' in u.lower(): s+=2
    if any(h in u for h in ('arxiv','researchgate','repository','.edu','ethz','ac.uk','.gov','osti','hal.')): s+=1
    if any(h in u for h in ('science.org','nature.com','springer','wiley','elsevier','sciencedirect','ametsoc','agu.org','copernicus','mdpi','frontiersin','thelancet')): s-=1
    return -s
for u in sorted(urls,key=score):
    print(u)
")
rm -f "$TMP"
if [ -z "$URLS" ]; then
  echo "{\"ok\": false, \"msg\": \"no OA location\"}"
  exit 0
fi
while IFS= read -r URL; do
  [ -z "$URL" ] && continue
  curl -sL --max-time 120 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "$URL" -o "$OUT" 2>/dev/null
  HEAD=$(head -c 4 "$OUT" 2>/dev/null)
  if [ "$HEAD" = "%PDF" ]; then
    SIZE=$(stat -c%s "$OUT")
    if [ "$SIZE" -gt 30000 ]; then
      echo "{\"ok\": true, \"url\": \"$URL\", \"size\": $SIZE}"
      exit 0
    fi
  fi
  rm -f "$OUT"
done <<< "$URLS"
echo "{\"ok\": false, \"msg\": \"all locations failed\"}"
