# Trạng thái bài nộp — 2026-11-11

Đây là bản triển khai để nhóm tiếp tục cấu hình và thu bằng chứng, **chưa phải bài nộp đã đạt đủ rubric**.

| Hạng mục | Trạng thái | Bằng chứng / phần còn thiếu |
|---|---|---|
| 10 màn S01–S10 + sign-in/profile/student web | Đã triển khai | lib/screens, golden widget test; chưa E2E Android thật |
| MVVM + Provider, tokens/components | Đã triển khai | lib/theme, widgets, services, viewmodels |
| Import, lịch, P/A, chốt, sửa, export | Unit/VM kiểm chứng | test và evidence/validation/flutter-test.txt |
| UI 360/412 dp | Widget kiểm chứng | evidence/ui; dữ liệu tổng hợp |
| Android debug APK | Build thành công | build/app/outputs/flutter-apk/app-debug.apk; chưa Firebase config |
| Flutter web | Build thành công | build/web; chưa deploy Hosting |
| Firebase adapter và security rules | Đã triển khai; 8 security tests emulator pass | Chưa project/billing/config/Console evidence |
| Google Sign-In thật | Chờ cấu hình | Không có authenticated Firebase CLI account |
| Storage / FCM / Analytics / Crashlytics / RC | Chờ cloud evidence | Không suy diễn từ emulator/golden |
| Drive OAuth / upload / conflict | Mã có; chưa chạy thật | Cần Google Cloud consent/API/test account |
| ARTEMIS 18×3 regression | Đã viết, chưa chạy device | Thiếu Android device/daemon/model key/test account |
| Exploratory Pro 15–30 phút | Chưa chạy | Cần session/trace và issue list thật |
| AI review | 8 findings local + fix commits | Chưa external PR review; user yêu cầu main |
| Report 10 trang / slides 15 trang | Bản tài liệu có trạng thái evidence | Bổ sung Console/ARTEMIS/video trước nộp |
| Demo video 5–10 phút | Kịch bản có, chưa quay | docs/demo-script.md |
| Figma đối chiếu / handoff đầy đủ | Thiếu file nguồn liên kết | DESIGN.md có các liên kết không nằm trong thư mục |

## Những việc nhóm cần thực hiện để hoàn tất rubric
1. Tạo Firebase project, thêm SHA, bật Google Auth, Firestore, Storage (chấp thuận billing nếu dùng), nhập config và deploy rules/Hosting.
2. Chạy trên thiết bị Android bằng dedicated test account; kiểm thử end-to-end cả ba workflow, student link hai tài khoản, native picker, offline, Drive.
3. Thu Console evidence đủ sáu dịch vụ và đối chiếu project ID.
4. Chạy ARTEMIS đủ 3 lần/ca + exploratory, điều tra mọi flaky, thay NOT RUN bằng kết quả thật.
5. Đối chiếu Figma, thêm ảnh Figma cạnh app; lấy PR review nếu giảng viên không chấp nhận local review.
6. Quay video theo kịch bản, cập nhật link, rebuild report/slide với bằng chứng mới; kiểm tra quyền xem repo và artifact.

Lịch sử commit phản ánh công việc thực tế trong một ngày; không tạo commit giả ngày hoặc giả nhiều ngày. Handout để `[N]` ngày/commits chưa có giá trị cụ thể, cần giảng viên xác nhận.
