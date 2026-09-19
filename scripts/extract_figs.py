# -*- coding: utf-8 -*-
"""Extract main-text figures from a PDF by locating caption labels (Fig. N / Figure N)
and rendering the region above each caption.
Usage: python extract_figs.py <in.pdf> <outdir> [max_figs]
Writes fig_1.png ... and figs.json [{"n":1,"page":0,"caption_start":"Fig. 1. ...","file":"fig_1.png"}]
Heuristic: on the page where "Fig. N." or "Figure N." caption begins, crop from below the
previous caption (or below page header) down to just above the caption start.
Falls back to rendering the full page if region detection fails.
"""
import sys, os, re, json

import pymupdf

CAP_RE = re.compile(r"(?:^|\s)(Fig(?:ure)?\.?\s*(\d{1,2}))[\.:)\s]", re.M)

def find_caption_instances(doc):
    """Return list of dicts: n, page, rect(of the caption label), caption_preview"""
    found = {}
    for pno in range(len(doc)):
        page = doc[pno]
        text = page.get_text("text")
        for m in CAP_RE.finditer(text):
            n = int(m.group(2))
            if n < 1 or n > 15:
                continue
            if n in found:
                continue
            # locate rects for the exact label occurrence
            label = m.group(1)
            rects = page.search_for(label)
            if not rects:
                continue
            # preview: text following the match
            preview = text[m.start():m.start() + 220].replace("\n", " ").strip()
            found[n] = {"n": n, "page": pno, "rects": [list(r) for r in rects],
                        "preview": preview}
    return [found[k] for k in sorted(found)]

def extract(pdf_path, outdir, max_figs=8):
    os.makedirs(outdir, exist_ok=True)
    doc = pymupdf.open(pdf_path)
    caps = find_caption_instances(doc)
    results = []
    for cap in caps[:max_figs]:
        n, pno = cap["n"], cap["page"]
        page = doc[pno]
        prect = page.rect
        # caption top y = min y0 of located label rects that look like a caption start
        ys = [r[1] for r in cap["rects"]]
        cap_top = min(ys)
        # figure region: from top margin (below header ~ 60pt) to just above caption
        top = max(prect.y0 + 55, prect.y0)
        # If another figure caption exists above on the same page, start below it
        for other in caps:
            if other["n"] != n and other["page"] == pno:
                oys = max(r[3] for r in other["rects"])
                if oys < cap_top - 30 and oys > top:
                    top = oys + 5
        bottom = cap_top - 4
        if bottom - top < 80:
            # caption likely at top; figure may be below caption (rare) -> use area below caption
            cbottom = max(r[3] for r in cap["rects"])
            top = cbottom + 4
            bottom = prect.y1 - 50
        if bottom - top < 80:
            clip = prect
        else:
            clip = pymupdf.Rect(prect.x0 + 40, top, prect.x1 - 40, bottom)
        mat = pymupdf.Matrix(2.2, 2.2)
        pix = page.get_pixmap(matrix=mat, clip=clip)
        fn = f"fig_{n}.png"
        pix.save(os.path.join(outdir, fn))
        results.append({"n": n, "page": pno, "file": fn,
                        "caption_preview": cap["preview"]})
    with open(os.path.join(outdir, "figs.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=1)
    print(json.dumps({"ok": True, "count": len(results),
                      "figs": [r["n"] for r in results]}, ensure_ascii=False))

if __name__ == "__main__":
    pdf, outdir = sys.argv[1], sys.argv[2]
    mf = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    try:
        extract(pdf, outdir, mf)
    except Exception as e:
        print(json.dumps({"ok": False, "msg": str(e)}))
