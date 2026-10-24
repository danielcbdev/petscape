#!/usr/bin/env python3
"""Refresh the offline M15 viewer without changing any runtime sprite.

Legacy V5 PNGs carry gAMA=2.19998, which browsers brighten unlike the native
ImageIO/CG bitmap decode. Review copies omit only that metadata chunk; IDAT
(pixel data), alpha, dimensions and all other chunks remain byte-identical.
Uses only the Python standard library.
"""
import json
import re
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/characters/cat"
REVIEW = ROOT / "docs/assets/v7"


def browser_copy(path):
    source = (PACK / path).read_bytes()
    chunks = [source[:8]]
    offset = 8
    removed = False
    while offset < len(source):
        length = struct.unpack(">I", source[offset:offset + 4])[0]
        chunk = source[offset:offset + length + 12]
        if chunk[4:8] == b"gAMA":
            removed = True
        else:
            chunks.append(chunk)
        offset += len(chunk)
    if removed:
        destination = REVIEW / "color-normalized" / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(b"".join(chunks))
    return removed


baseline = json.loads((PACK / "v7/baseline-character.json").read_text())
current = json.loads((PACK / "character.json").read_text())
paths = sorted({f["image"] for c in current["animations"].values() for f in c["frames"]})
normalized = [path for path in paths if browser_copy(path)]
viewer = REVIEW / "preview.html"
text = viewer.read_text()
start = text.index("<script>const baseline=")
end = text.index(",root=", start)
text = (text[:start] + "<script>const baseline=" + json.dumps(baseline)
        + ",current=" + json.dumps(current) + text[end:])
text = re.sub(r";const normalized=.*?;(?=let running=true)", ";", text)
text = text.replace(";let running=true", ";const normalized=" + json.dumps(normalized) + ";let running=true")
text = text.replace("p.img.src=root+frame.image", "p.img.src=(normalized.includes(frame.image)?'color-normalized/':root)+frame.image")
viewer.write_text(text)
print(f"Refreshed manifests, {len(paths)} sprites and {len(normalized)} browser color copies")
