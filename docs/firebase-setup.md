# Thiết lập Firebase cho nhóm 3

## Trạng thái hiện tại
Nhóm chưa có Firebase project ID. Firebase CLI trên máy chưa đăng nhập. APK hiện build được nhưng mở màn “Cần kết nối Firebase”; không có tài khoản giả hay mock data trong production. Các test emulator không chứng minh kết nối cloud thật.

## 1. Tạo project và đăng ký Android
1. Vào Firebase Console bằng tài khoản của nhóm, tạo project (tên gợi ý `FAP Attendance Group 3`), bật Analytics.
2. Đăng ký Android package **vn.edu.fpt.fap_attendance**.
3. Lấy SHA-1/SHA-256 bằng `cd android` rồi `./gradlew signingReport`; thêm cả hai vào Firebase Project settings.
4. Bật Authentication → Google, nhập support email. Dùng tài khoản kiểm thử riêng khi quay demo.
5. Tải `google-services.json` mới sau khi cấu hình OAuth và đặt tại `android/app/google-services.json`. File này chứa cấu hình ứng dụng, không phải service account key.
6. `dart pub global activate flutterfire_cli`, `npx firebase login`, rồi `flutterfire configure --project=<PROJECT_ID> --platforms=android,web`. CLI có thể tạo lib/firebase_options.dart; app hiện đọc config native trên Android và `--dart-define-from-file` trên web.

## 2. Database, Storage và rules
Tạo Cloud Firestore ở chế độ production. Chọn region phù hợp trước khi tạo vì không thể đổi đơn giản. Ứng dụng lưu dữ liệu ở `workspaces/{uid}` và dùng revision transaction chống ghi đè.

Cloud Storage hiện cần **Blaze + billing**. Không bật billing tự động. Nội dung handout “Spark đủ” không còn đúng với Storage hiện hành. Tham khảo [Firebase Storage billing requirements](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024). Nếu nhóm không dùng billing, cần giảng viên chấp thuận phương án thay thế; emulator không thay bằng chứng cloud.

Sau khi project và bucket đã sẵn sàng:
```powershell
npx firebase use --add
npx firebase deploy --only firestore:rules,storage --project <PROJECT_ID>
```
Firestore chỉ owner đọc/ghi workspace; sinh viên chỉ đọc member document của email đã xác thực. Link submissions yêu cầu visit 120 giây, code đúng nếu bật, chưa dừng. Storage giới hạn `reports/{uid}/...`, JSON/CSV, dưới 10 MB.

## 3. Trang sinh viên và URL link
Tạo Firebase Web app và bật Google provider cho domain Hosting. Sao chép `config/firebase.example.json` sang `config/firebase.local.json`, điền Web app config của đúng project. Các key ở đây là client config, không chứa service account hoặc khóa mô hình.
```powershell
flutter build web --dart-define-from-file=config/firebase.local.json
npx firebase deploy --only hosting --project <PROJECT_ID>
flutter run --dart-define=ATTENDANCE_BASE_URL=https://<PROJECT_ID>.web.app
```
Trong config local, ATTENDANCE_BASE_URL là HTTPS URL vừa deploy. Sinh viên truy cập `/?session=...`, đăng nhập Google và xác nhận. Không dùng email nhập tay để thay xác thực. Trong Android build, Google Services plugin chỉ được apply khi file config có thật.

## 4. Remote Config, Analytics và Crashlytics
Tạo `attendance_link_enabled` (Boolean, true), `absence_warning_percent` (Number, 20) theo file defaults. Publish, đợi ít nhất 1 phút rồi nhấn Tải cấu hình mới. Flag điều khiển tạo link; threshold điều khiển cảnh báo S07. Khi fetch lỗi app giữ config hiện tại/default và báo lỗi.

```powershell
adb shell setprop debug.firebase.analytics.app vn.edu.fpt.fap_attendance
adb shell setprop log.tag.FA VERBOSE
adb shell setprop log.tag.FA-SVC VERBOSE
```
Đăng nhập đặt UID; thao tác đủ event trong analytics-plan. Chụp DebugView tên/params, không có email/MSSV/tên/lý do. Nhập file hỏng tạo lỗi đã xử lý thật. Trong Profile xác nhận nút crash thử nghiệm, mở lại app và kiểm tra Crashlytics. Chụp UID + `app_area` + `operation`. Không đưa crash vào flow dùng bình thường.

## 5. Cloud Messaging
Android 13+ xin quyền qua Profile. SDK lưu token tại `users/{uid}/devices/{token}`. Gửi test message từ Console với data keys `classId` và `meetingId` lấy từ dữ liệu test đã import; không đưa tên/MSSV vào push payload.
Chụp riêng ba trạng thái: foreground, background, terminated. Với notification payload, Android có thể chỉ chuyển message cho app khi người dùng tap; danh sách local ghi khi SDK callback/tap giao message cho app. Muốn lưu cả notification chưa mở khi app bị kill cần thêm server inbox (chưa triển khai).

## 6. Google Drive
Bật Google Drive API trong cùng Google Cloud project, cấu hình OAuth consent và test users. App dùng scope `drive.file`: chỉ thấy file app tạo hoặc được cấp quyền, không quét toàn Drive. Trên Android có thể import markbook từ Drive qua native document picker. Upload lưu file ID/version/hash để hạn chế bản sao và phát hiện conflict. Khi token hết hạn, kết nối lại; khi có conflict app giữ file local.

## Bằng chứng cần thu thập
Xem `evidence/README.md`. Mọi ảnh Console phải hiện đúng project ID trùng google-services.json. Không dùng ảnh minh họa/golden test thay chứng cứ Firebase thật.
