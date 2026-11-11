# Test plan

## Mức kiểm thử
1. Unit / ViewModel: luật P/A, import ODS/XLSX thật, serialization, export, persistence failure, revision conflict.
2. Widget: 360/412 dp, tên dài, đổi P/A, lý do trắng/hủy, cột slot cố định. Golden là dữ liệu tổng hợp trong `test/support.dart`, **không phải screenshot production**.
3. Firebase Emulator: quyền owner, student membership, verified email, private code, visit 120 giây, stop, idempotence, per-user Storage. Emulator không thay Console evidence.
4. Google ARTEMIS: 18 ca regression × 3 lượt, một phiên Pro 15–30 phút. Chưa chạy khi thiếu device/daemon/model key/Firebase.

## Các workflow và ca ARTEMIS
Điều kiện chung: Android cài APK đã cấu hình Firebase thật, dedicated Google account, markbook fixture tải vào Downloads, không dữ liệu sinh viên thật. Mỗi instruction tự lập precondition và học kỳ riêng, không phụ thuộc thứ tự test.

| ID | Flow / màn | Điều kiện và chỉ dẫn chính | Expected / structured assertions | Nhánh |
|---|---|---|---|---|
| TC01 | Auth / Sign-in | Signed out; Google picker; chọn test account | signed_in=true, account_picker_seen=true; Logcat login | Native |
| TC02 | Auth | Signed out; mở rồi hủy picker | signed_in=false, cancellation_visible=true | Cancel |
| TC03 | WF01 S01/03/02/08 | Import fixture 2 SV, 2 tuần; preview rồi confirm | student_count=2, meeting_count=2 | Main |
| TC04 | WF01 S03 | Chọn invalid.xlsx; preview; chọn lại | error_visible=true, confirm_visible=false | Error/recovery |
| TC05 | WF01 S05/S04 | Bắt đầu meeting rồi đổi số tuần | locked_message_visible=true, unchanged_meeting_count=2 | Forbidden transition |
| TC06 | WF02 S04 | P một SV; đổi mode; hủy chốt rồi chốt | P=1, A=1, unknown=0, Đã chốt | Main + cancel |
| TC07 | WF02 S04 | Search chuỗi không có; clear | 0 kết quả, empty; restored=2 | Empty/recovery |
| TC08 | WF02 S04 | Cache roster; Android network off; ghi P; reopen | present=1, local_saved_visible=true | Offline/native |
| TC09 | WF02 S06 | Tạo link code, copy, back/reopen, stop | link visible, 6 digits, receiving=false, closed=false | Link/stop |
| TC10 | WF03 S07 | A một SV trong 2 meeting; mở detail | MSSV đúng, absence=50% | Detail |
| TC11 | WF03 S07 | P → A với reason spaces; cancel | reason error, P vẫn 1 | Validation/cancel |
| TC12 | WF03 S08/07/04 | Closed meeting; sửa P → A có reason | audit before/after/reason; A=2 | Audit |
| TC13 | WF03 S09 | Close P1/A1; JSON local + Storage | json, progress=100, URL, counts; Logcat upload_report | Native/cloud |
| TC14 | WF03 S09 | CSV, hủy native save | cancellation=true, saved_success=false | Cancel |
| TC15 | S02/S10 | Lịch → Drive → Lịch | Drive seen, calendar mode preserved | Navigation |
| TC16 | Profile/S04 | Operator publish false/40; refresh | false, 40, create link disabled | RC behaviour |
| TC17 | Profile/S04 | Grant native permission; operator FCM; tap shade | relevant roster and inbox item | Native/FCM |
| TC18 | Auth/Profile | Sign out and system Back | sign-in visible, protected screen false | Privacy |
| EXP01 | All | 15–30 phút Pro unscripted, synthetic classes | issue list + screenshots + elapsed time | Exploratory |

Instruction đầy đủ, schema output và assertions nằm trong `e2e_test/test_*.py`. SDK pin commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b`; API thực tế dùng `result.succeeded` và `result.output` chứ không giả định status chuỗi SUCCESS. Expected output là kiểu field, agent phải quan sát giá trị; pytest so sánh từng giá trị. Thiếu JSON hoặc sai giá trị đều fail.

## Chạy và lưu evidence
```powershell
flutter test --reporter expanded
npm ci
npm run test:rules
cd e2e_test
uv sync
$env:ARTEMIS_BASE_URL='http://127.0.0.1:8000'
$env:ANDROID_SERIAL='<adb-serial>'
$env:E2E_GOOGLE_ACCOUNT='<dedicated-account>'
uv run pytest -m 'not exploratory' -v
uv run python summarize.py
$env:RUN_EXPLORATORY='1'
uv run pytest -m exploratory -k run-1 -v
```
ARTEMIS daemon/model API key cấu hình bên ngoài repo theo README chính thức tại commit pin. Không mở daemon lên internet. Fixture `repetition` tự chạy mỗi regression 3 lần. `evidence/artemis/<case-run-time>/result.json` chứa trace; tải screenshot/replay từ daemon cùng trace ID. `summarize.py` tổng hợp chỉ kết quả đã chạy. Không có evidence → NOT RUN.

## Flakiness và giới hạn
Không đạt 3/3 là flaky. Phân loại app / timing / instruction / infrastructure; ghi reproduction, sửa và chạy lại đủ 3. Fail assertion Analytics nếu Logcat không ghi được event, kiểm tra debug props và DebugView, không bỏ assertion để lấy pass. TC16/17 cần operator chuẩn bị Console; ghi rõ precondition nếu chưa có. Kiểm thử submission thật giữa hai tài khoản/thiết bị, ba trạng thái FCM, token expiry và Drive conflict còn cần thực hiện trên cấu hình của nhóm.
