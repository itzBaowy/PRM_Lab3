"""Real ARTEMIS adapter. Missing infrastructure is a skip, never a pass."""
import json
import os
import subprocess
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "vn.edu.fpt.fap_attendance"


@pytest.fixture(params=[1, 2, 3], ids=lambda value: f"run-{value}")
def repetition(request):
    return request.param


@pytest.fixture
def artemis(repetition):
    url = os.getenv("ARTEMIS_BASE_URL")
    serial = os.getenv("ANDROID_SERIAL")
    account = os.getenv("E2E_GOOGLE_ACCOUNT")
    if not all([url, serial, account]):
        pytest.skip("Requires ARTEMIS_BASE_URL, ANDROID_SERIAL and a dedicated E2E_GOOGLE_ACCOUNT")
    from artemis_client import ArtemisClient
    return ArtemisClient(url, token=os.getenv("ARTEMIS_TOKEN"), device_serial=serial, default_profile="flash")


@pytest.fixture
def run_case(artemis, repetition, request):
    async def execute(case_id, instruction, expected, *, analytics=None, profile="flash", timeout=600):
        account = os.environ["E2E_GOOGLE_ACCOUNT"]
        serial = os.environ["ANDROID_SERIAL"]
        # Start each test independently; the instruction must establish its own fixture.
        subprocess.run(["adb", "-s", serial, "shell", "am", "force-stop", PACKAGE], check=True)
        subprocess.run(["adb", "-s", serial, "shell", "setprop", "debug.firebase.analytics.app", PACKAGE], check=True)
        subprocess.run(["adb", "-s", serial, "logcat", "-c"], check=True)
        output_dir = ROOT / "evidence" / "artemis" / f"{case_id}-run-{repetition}-{time.time_ns()}"
        output_dir.mkdir(parents=True)
        started = time.monotonic()
        report = {"case_id": case_id, "run": repetition, "status": "failed", "test": request.node.name}
        try:
            result = await artemis.run(
                f"Use ONLY the dedicated Google test account {account}. "
                "Do not use personal accounts. Open FAP Attendance. "
                "Establish all stated preconditions even if another test left different data. "
                + instruction
                + " Return a JSON object containing the requested observed values. "
                "Read visible values; do not copy the expected values from this instruction. "
                "Capture screenshots at verification points and retain the trace.",
                expected_output=json.dumps({key: type(value).__name__ for key, value in expected.items()}),
                enable_outputter=True,
                profile=profile,
                timeout=timeout,
            )
            (output_dir / "result.json").write_text(json.dumps(result.raw, ensure_ascii=False, default=str, indent=2), encoding="utf-8")
            report.update(trace_id=result.trace_id, duration_seconds=round(time.monotonic()-started, 2))
            assert result.succeeded, result.error or result.status
            observed = result.output
            if isinstance(observed, str):
                observed = json.loads(observed.strip().removeprefix("```json").removesuffix("```").strip())
            assert isinstance(observed, dict), f"Missing structured observations: {observed!r}"
            for key, value in expected.items():
                assert observed.get(key) == value, f"{key}: observed={observed.get(key)!r}, expected={value!r}"
            if profile == "pro":
                assert 900 <= report["duration_seconds"] <= 1800, "Exploration must actually last 15–30 minutes"
                assert isinstance(observed.get("issues"), list), "Exploratory report must contain observed issues (possibly empty)"
            logcat = subprocess.run(["adb", "-s", serial, "logcat", "-d"], check=True, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
            # Raw Logcat can include device PII. Retain only app analytics evidence.
            event_lines = [line for line in logcat.splitlines() if "FA" in line and (analytics or "fap_attendance") in line]
            (output_dir / "analytics.txt").write_text("\n".join(event_lines), encoding="utf-8")
            if analytics:
                assert any(analytics in line for line in event_lines), f"No Logcat evidence for {analytics}; inspect DebugView and logging configuration"
            report["status"] = "passed"
            return observed
        finally:
            report.setdefault("duration_seconds", round(time.monotonic()-started, 2))
            (output_dir / "summary.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return execute
