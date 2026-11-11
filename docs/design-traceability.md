# Truy vết Lab 2 → Lab 3

Nguồn: `DESIGN.md`, Lab 3 requirement (18 trang), Preparation Guide (25 trang), Workflow (15 trang). Nội dung requirement quy định **Google ARTEMIS**, dù tên tệp có Patrol. Đề tài giữ nguyên FAP Attendance Mobile.

## Màn hình

| ID | Route | View / widget | ViewModel | Dữ liệu |
|---|---|---|---|---|
| S01 | /workspace | WorkspaceScreen | WorkspaceVm | Tài khoản xác thực, workspace local |
| S02 | /home | HomeScreen / MeetingCell | WorkspaceVm | Lớp, meeting từ markbook + Firestore |
| S03 | /import | ImportScreen | ImportVm | ODS/XLSX người dùng chọn, preview trước lưu |
| S04 | /attendance | AttendanceScreen / StudentRow | WorkspaceVm | Kết quả một meeting, local + Firestore |
| S05 | /schedule | ScheduleScreen | WorkspaceVm | Lịch, ngày nghỉ, học bù |
| S06 | /link | LinkScreen | LinkVm | Phiên link Firebase, xác nhận sinh viên |
| S07 | /student | StudentScreen / EditAttendanceSheet | WorkspaceVm | P/A, lý do, audit |
| S08 | /history | HistoryScreen | WorkspaceVm | Meeting của lớp được chọn |
| S09 | /export | ExportScreen | ExportVm | JSON/CSV từ meeting đã chốt |
| S10 | /drive | DriveScreen | DriveVm | Google Drive API, trạng thái sync |
| bổ sung | /signin | SignInScreen | AuthVm | Firebase Auth + Google Sign-In |
| bổ sung | /profile | ProfileScreen | ProfileVm | Remote Config, FCM, Crashlytics |

## Flow và component

WF-01 nhập và cấu hình: S01 → S03 (preview, invalid/cancel/retry) → S02 → S05 (khóa khi lớp đã bắt đầu).
WF-02 ghi nhận và chốt: S02 → S04 ↔ S06 (link/manual, offline, duplicate, hủy chốt) → closed.
WF-03 điều chỉnh và bàn giao: S08 → S07 (reason required, cancel/retry) → S09 (local export, upload retry) → S10.

`lib/theme/app_theme.dart` là nguồn token duy nhất. `lib/widgets/app_widgets.dart` chứa AppButton, AppField, AppCard, AppPage, StatePanel, AppNavigation, ConfirmDialog, AttendanceStatus, StudentRow, MeetingCell. Material cung cấp pressed/focus/disabled và semantics, widget chung thêm loading/error.

## Khác biệt có lý do

1. Thêm Google Sign-In và Profile vì Lab 3 §3/§6 bắt buộc. Email nhận diện S01 không thay Firebase identity. Hai tab cấp cao vẫn là Lịch tuần và Drive; Profile mở từ app bar.
2. Giữ lưu local để điểm danh offline, thêm Firestore theo Lab 3 §3 cho dữ liệu người dùng. Cloud Storage là đích upload bắt buộc; Drive là lựa chọn riêng của Lab 2.
3. Trang sinh viên qua link nằm ngoài S01–S10, dùng Firebase Auth để kiểm tra email thực và rules để chống sửa P/A của giảng viên.
4. Chưa có các tệp Figma/handoff/ảnh được liên kết tương đối trong DESIGN.md. Dùng đặc tả văn bản được cung cấp; đối chiếu pixel và cập nhật Figma cần bản thiết kế của nhóm.
5. Không nạp dữ liệu mẫu vào production. Fixture chỉ ở test/fixtures và được import rõ ràng khi kiểm thử.

Trạng thái thực thi và bằng chứng cuối được ghi ở `docs/submission-status.md`; bảng trên là hợp đồng triển khai, không phải bằng chứng chạy thật.
