from test_workflows import SETUP

async def test_tc13_export_upload(run_case):
    await run_case("TC13", SETUP + "Begin today's meeting, mark first student Present, close. Open Xuất kết quả, choose JSON, create file, save through native Android file picker, then Upload Cloud Storage. Wait for completion. Report file_extension, progress_percent, download_url_visible, present and absent.", {"file_extension": "json", "progress_percent": 100, "download_url_visible": True, "present": 1, "absent": 1}, analytics="upload_report")

async def test_tc14_cancel_export(run_case):
    await run_case("TC14", SETUP + "Begin and close today's meeting. Generate CSV, tap Lưu trên thiết bị then cancel native save dialog. Report cancellation_visible=true and saved_success_visible=false. Return and verify the generated filename still ends with .csv.", {"cancellation_visible": True, "saved_success_visible": False, "file_extension": "csv"})

async def test_tc15_top_level_drive(run_case):
    await run_case("TC15", SETUP + "Switch to calendar view, then open Drive from bottom navigation, observe local sync status. Return to Lịch tuần & lớp using its bottom tab. Report drive_title_seen and calendar_mode_preserved.", {"drive_title_seen": True, "calendar_mode_preserved": True})

async def test_tc16_remote_config(run_case):
    await run_case("TC16", "Precondition: test operator has published attendance_link_enabled=false and absence_warning_percent=40 in the same Firebase project at least one minute ago. Sign in and open Hồ sơ & Firebase. Tap Tải cấu hình mới. Report link_enabled=false and warning_percent=40. Open an active roster and Qua link; confirm create_link_disabled=true without rebuilding.", {"link_enabled": False, "warning_percent": 40, "create_link_disabled": True})

async def test_tc17_notification(run_case):
    await run_case("TC17", "Precondition: sign in, have an imported class and operator-prepared FCM message with valid classId/meetingId for this device. Open Profile, request notification permission and grant native dialog if present. Background the app and wait for the operator message. Tap it from Android notification shade. Verify relevant attendance screen. Open Profile notification center. Report attendance_opened and notification_list_contains_message.", {"attendance_opened": True, "notification_list_contains_message": True})
