#!/usr/bin/env python3
"""Assemble archive.zip from pieces/ according to pieces/plan.json (no learning, no evaluator)."""
import hashlib
import json
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build" / "archive.zip"
plan = json.loads((ROOT / "pieces" / "plan.json").read_text())

parts = []
for s in plan["sections"]:
    b = (ROOT / "pieces" / s["file"]).read_bytes()
    if len(b) != s["bytes"] or hashlib.sha256(b).hexdigest() != s["sha256"]:
        raise SystemExit(f"piece mismatch: {s['file']}")
    parts.append(b)
ext = parts[-1]
warp = parts[-2]
payload = b"".join(parts) + len(ext).to_bytes(2, "little") + (len(warp) + len(ext) + 2).to_bytes(2, "little")
if len(payload) != plan["payload_bytes"] or hashlib.sha256(payload).hexdigest() != plan["payload_sha256"]:
    raise SystemExit("payload mismatch")

z = plan["zip"]
info = zipfile.ZipInfo(filename=plan["member"], date_time=tuple(z["date_time"]))
info.compress_type = zipfile.ZIP_STORED
info.create_system = z["create_system"]
info.external_attr = z["external_attr"]
info.extract_version = z["extract_version"]
info.flag_bits = z["flag_bits"]
out.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as zf:
    zf.writestr(info, payload)

data = out.read_bytes()
sha = hashlib.sha256(data).hexdigest()
print(f"expected {plan['archive_sha256']}\nactual   {sha}\nsize     {len(data)} (expected {plan['archive_bytes']})")
if sha != plan["archive_sha256"] or len(data) != plan["archive_bytes"]:
    print("FAIL")
    raise SystemExit(1)
print("PASS")
