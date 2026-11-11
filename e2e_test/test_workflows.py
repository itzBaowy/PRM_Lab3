SETUP = "Precondition: sign in. Import /sdcard/Download/lab3-fixture.xlsx (exactly two synthetic students) into a fresh semester named after this test and current time. Set start date to today, 2 weeks, one slot per week on today's weekday. Verify the preview and confirm. Stop/close any other active meeting first. "

async def test_tc03_import_preview(run_case):
    await run_case("TC03", SETUP + "Open the imported class history. Report student_count from the class card and meeting_count from the configured history.", {"student_count": 2, "meeting_count": 2})

async def test_tc04_bad_import(run_case):
    await run_case("TC04", "Sign in. Open Import markbook. Choose /sdcard/Download/invalid.xlsx, set a semester, then Kiểm tra & xem trước. Report error_visible=true if a readable parse error appears, confirm_visible=false if no stale Xác nhận import is available. Reopen the picker to demonstrate recovery without leaving the screen.", {"error_visible": True, "confirm_visible": False})

async def test_tc05_schedule_lock(run_case):
    await run_case("TC05", SETUP + "Begin today's meeting. Back to the class and open Cấu hình lịch. Change weeks to 3 and try Lưu lịch lớp. Verify a message explains the schedule is locked because attendance started. Report locked_message_visible and unchanged_meeting_count.", {"locked_message_visible": True, "unchanged_meeting_count": 2})

async def test_tc06_manual_close(run_case):
    await run_case("TC06", SETUP + "Open today's meeting, begin, select Thủ công. Mark only SE000001 Present. Change mode to Qua link then back without creating a link. Tap Chốt danh sách; read the dialog showing one unknown will become Absent; cancel once and verify still active. Confirm close on the second attempt. Report present, absent, unknown and state_label from the final screen.", {"present": 1, "absent": 1, "unknown": 0, "state_label": "Đã chốt"})

async def test_tc07_empty_search(run_case):
    await run_case("TC07", SETUP + "Open today's roster, search for NEVER_MATCH_78291. Report result_count and empty_message_visible. Clear search and report restored_count.", {"result_count": 0, "empty_message_visible": True, "restored_count": 2})

async def test_tc08_offline_manual(run_case):
    await run_case("TC08", SETUP + "Open today's meeting, begin. Use native Android quick settings to disable network. Mark SE000001 Present, navigate Back and reopen the same meeting. Report present and local_saved_visible. Restore network before finishing, including if the test fails.", {"present": 1, "local_saved_visible": True})

async def test_tc09_link_pause(run_case):
    await run_case("TC09", SETUP + "Ensure Remote Config attendance_link_enabled is true. Begin today's meeting, select Qua link, create link with 6-digit code, copy it. Return to roster and back into link management. Stop receiving. Report link_visible, code_digits, receiving and closed. Do not assert any student is Present merely from opening/copying the link.", {"link_visible": True, "code_digits": 6, "receiving": False, "closed": False})

async def test_tc10_student_details(run_case):
    await run_case("TC10", SETUP + "Begin today's meeting, mark SE000001 Absent, open this student's details by tapping their name. Report student_id and absence_percent, including all two scheduled meetings in the denominator.", {"student_id": "SE000001", "absence_percent": 50.0})

async def test_tc11_reason_validation(run_case):
    await run_case("TC11", SETUP + "Begin today's meeting, mark SE000001 Present, open student detail and Sửa P/A. Select Absent, enter spaces as the reason, tap Lưu thay đổi. Report reason_error_visible=true if Vui lòng nhập lý do chỉnh sửa appears. Cancel; report present remains 1 in the roster.", {"reason_error_visible": True, "present": 1})

async def test_tc12_edit_audit(run_case):
    await run_case("TC12", SETUP + "Begin today's meeting, mark SE000001 Present and close the meeting. Open student detail, change to Absent with new reason 'E2E correction'. Save. Expand Xem ghi chú & lịch sử sửa. Report before='Present', after='Absent', reason='E2E correction'. Reopen roster and report absent=2.", {"before": "Present", "after": "Absent", "reason": "E2E correction", "absent": 2})
