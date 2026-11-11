# Evidence index

- `validation/flutter-test.txt`: log unit/widget thật.
- `validation/flutter-analyze.txt`: Dart analyzer.
- `validation/android-build.txt`: Android debug build thật; APK chưa cấu hình Firebase nếu chưa có google-services.json.
- `validation/web-build.txt`: Flutter web compiler.
- `validation/security-rules.txt`: Firebase Emulator run; permission-denied trong negative test là expected.
- CLI debug từng ghi environment vào log; toàn bộ environment được thay bằng `[REDACTED_ENVIRONMENT]` để loại khóa và thông tin máy, giữ nguyên kết quả kiểm thử.
- `ui/*.png`: golden render từ Flutter widget tests, fixture tổng hợp (không phải Firebase/thiết bị thật).
- Pixel golden được so trên Windows; CI Linux vẫn chạy mọi assertion tương tác và overflow, bỏ so pixel vì font rasterization khác hệ điều hành.
- `artemis/results.md`: NOT RUN đến khi có trace thật.

## Chưa có và phải bổ sung trước khi nộp
1. `firebase/auth`: signed-in, signed-out, native cancel, Users Console.
2. `firebase/storage`: file list owner path, progress, URL, cross-account denied.
3. `firebase/fcm`: foreground/background/terminated, permission, inbox, deep link.
4. `firebase/analytics`: DebugView mọi event và parameters theo docs/analytics-plan.md.
5. `firebase/crashlytics`: nonfatal thật, test crash, UID và custom key.
6. `firebase/remote-config`: Console và trước/sau hành vi flag/threshold.
7. `artemis`: 3 run/case, trace screenshots/replay, exploratory 15–30 phút.
8. `review`: PR/tool output nếu giảng viên yêu cầu PR review ngoài local Codex review.
9. `video`: link demo 5–10 phút, kiểm tra xem được bằng trình duyệt private.

Không dùng ảnh minh họa hoặc log dựng sẵn làm bằng chứng. Ẩn email, token, tên sinh viên thật và dữ liệu nhạy cảm trước khi commit; giữ project ID để đối chiếu.
