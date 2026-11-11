import json
from pathlib import Path
from collections import defaultdict

root = Path(__file__).resolve().parents[1]
cases = defaultdict(list)
for file in (root / "evidence/artemis").glob("*/summary.json"):
    row = json.loads(file.read_text(encoding="utf-8"))
    cases[row["case_id"]].append(row)
lines = ["# ARTEMIS results", "", "| Case | Runs | Passed | Pass rate | Mean seconds |", "|---|---:|---:|---:|---:|"]
for case, rows in sorted(cases.items()):
    passed = sum(row["status"] == "passed" for row in rows)
    lines.append(f"| {case} | {len(rows)} | {passed} | {passed/len(rows):.0%} | {sum(row['duration_seconds'] for row in rows)/len(rows):.1f} |")
if not cases:
    lines.extend(["", "NOT RUN: no real ARTEMIS run evidence is present. This is not a passing result."])
(root / "evidence/artemis/results.md").parent.mkdir(parents=True, exist_ok=True)
(root / "evidence/artemis/results.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
