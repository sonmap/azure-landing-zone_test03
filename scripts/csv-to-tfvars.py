#!/usr/bin/env python3
import csv
import json
import re
import sys
from pathlib import Path


if len(sys.argv) != 3:
    raise SystemExit("usage: csv-to-tfvars.py <input.csv> <output.tfvars>")

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])


def to_hcl(value: str) -> str:
    value = value.strip()
    if value == "":
        return '""'
    if value.lower() in {"true", "false"}:
        return value.lower()
    if re.fullmatch(r"-?\d+(\.\d+)?", value):
        return value
    if (value.startswith("[") and value.endswith("]")) or (value.startswith("{") and value.endswith("}")):
        try:
            json.loads(value)
            return value
        except json.JSONDecodeError:
            pass
    return json.dumps(value, ensure_ascii=False)


rows = []
with input_path.open("r", encoding="utf-8-sig", newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        name = (row.get("name") or "").strip()
        value = row.get("value") or ""
        if name:
            rows.append((name, value))

if not rows:
    raise SystemExit(f"no variables found in {input_path}")

with output_path.open("w", encoding="utf-8", newline="\n") as f:
    for name, value in rows:
        f.write(f"{name} = {to_hcl(value)}\n")
