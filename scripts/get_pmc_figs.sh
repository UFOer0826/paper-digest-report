#!/bin/bash
# Download main-text figure images from a PMC article page.
# Usage: get_pmc_figs.sh <PMCID e.g. PMC7209987> <outdir>
# Downloads figure jpgs and prints list of saved files.
PMCID="$1"
OUTDIR="$2"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
mkdir -p "$OUTDIR"
HTML="$OUTDIR/_article.html"
curl -s --ssl-no-revoke -L --max-time 60 -A "$UA" "https://www.ncbi.nlm.nih.gov/pmc/articles/${PMCID}/" -o "$HTML"
URLS=$(grep -o 'cdn.ncbi.nlm.nih.gov/pmc/blobs[^"]*\.\(jpg\|png\|gif\)' "$HTML" | sort -u)
N=0
for U in $URLS; do
  FN=$(basename "$U")
  # skip supplementary (usually named *-s* or supp) heuristics: keep only files that look like F\d+
  case "$FN" in
    *-F[0-9]*|*fig[0-9]*|*FIG[0-9]*|*f[0-9].jpg|*f[0-9].png) ;;
    *) continue ;;
  esac
  curl -s --ssl-no-revoke -L --max-time 60 -A "$UA" "https://$U" -o "$OUTDIR/$FN"
  SZ=$(stat -c%s "$OUTDIR/$FN" 2>/dev/null || echo 0)
  if [ "$SZ" -gt 8000 ]; then
    echo "$FN $SZ"
    N=$((N+1))
  else
    rm -f "$OUTDIR/$FN"
  fi
done
echo "TOTAL $N"
