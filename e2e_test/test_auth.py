async def test_tc01_google_signin(run_case):
    await run_case("TC01", "Precondition: sign out if currently authenticated, confirming local cleanup. Tap Đăng nhập bằng Google, use the native account picker and select the dedicated test account. At the end report signed_in=true only if Bắt đầu workspace or Lịch tuần & lớp is visible, and account_picker_seen=true only if the Android picker was observed.", {"signed_in": True, "account_picker_seen": True}, analytics="login")


async def test_tc02_cancel_signin(run_case):
    await run_case("TC02", "Precondition: sign out. Tap Google sign-in then cancel the native picker using Back. Verify the sign-in screen remains and a cancellation message is visible. Report signed_in and cancellation_visible.", {"signed_in": False, "cancellation_visible": True})


async def test_tc18_signout(run_case):
    await run_case("TC18", "Precondition: sign in with the test account. Stop any open attendance link. Open Hồ sơ & Firebase, tap Đăng xuất and confirm. Press Android Back. Report sign_in_visible and protected_screen_visible at the end. No roster or profile may remain visible.", {"sign_in_visible": True, "protected_screen_visible": False})
