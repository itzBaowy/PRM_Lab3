import os
import pytest

@pytest.mark.exploratory
async def test_pro_exploration(run_case):
    if os.getenv("RUN_EXPLORATORY") != "1":
        pytest.skip("Opt in with RUN_EXPLORATORY=1 for a timed Pro exploration")
    await run_case("EXP01", "Explore FAP Attendance for 15–30 minutes, not a scripted tour. Focus on interrupted imports, rapid double taps, Vietnamese long names, keyboard over edit sheets, offline recovery, midnight boundaries, system Back and notification navigation. Keep changes confined to synthetic test classes. Return exploration_completed=true, plus a list named issues with observed behavior, reproduction, expected behavior and screenshot references. Preserve all traces. Do not invent findings if none are observed.", {"exploration_completed": True}, profile="pro", timeout=2100)
