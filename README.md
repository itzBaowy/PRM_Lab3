# FAP Attendance Mobile · PRM393 Lab 3

**Nhóm 3 · Khưu Gia Bảo · SE190145**
Repository: https://github.com/itzBaowy/PRM_Lab3
Triển khai theo `DESIGN.md` và ba PDF hướng dẫn trong thư mục gốc. Nội dung Lab 3 yêu cầu **Google ARTEMIS**, không dùng Patrol dù tên PDF còn ghi Patrol.

Ứng dụng Flutter Android quản lý lịch lớp, import ODS/XLSX, điểm danh qua link hoặc thủ công, chốt, sửa có lý do/audit, xuất JSON/CSV, đồng bộ Firestore và upload Cloud Storage/Drive. Giữ 10 màn S01–S10, thêm Google sign-in, Profile và trang web xác nhận cho sinh viên.

## Trạng thái bàn giao

- Mã nguồn, service Firebase, security rules, unit/widget tests và ARTEMIS suite đã có.
- Build Android debug và web đã chạy được; xem log tại `evidence/validation/`.
- **Nhóm chưa có Firebase project**. APK chưa cấu hình hiển thị “Cần kết nối Firebase”; chưa chứng minh Google sign-in/6 dịch vụ trên cloud thật.
- Golden UI dùng dữ liệu test tổng hợp, không thay evidence thiết bị/Console.
- ARTEMIS thiết kế 18 regression × 3 lần + Pro exploration; cần Android device, daemon và model API key để chạy.
- Report/slide ghi rõ phần đã kiểm chứng và phần chưa chạy. Video demo thật: **chưa có link**, kịch bản ở `docs/demo-script.md`.
- Giao thẳng `main` theo yêu cầu của người dùng. Local Codex review có 8 findings và commit fixes; PR review bên ngoài chưa thực hiện.

Chi tiết: [submission-status](docs/submission-status.md), [Firebase setup](docs/firebase-setup.md), [evidence index](evidence/README.md).

## Chạy ứng dụng

Yêu cầu Flutter **3.47.4**, Dart **3.13.3**, JDK **21**, Android SDK platform/build-tools **36**, Android min SDK **24**. Khai báo thư viện ở pubspec.yaml; phiên bản đã kiểm tra được khóa trong pubspec.lock. Node **24.19.0** cho rules tests; Python **3.12+** cho ARTEMIS.

```powershell
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
```

Để app sử dụng Firebase thật, làm [docs/firebase-setup.md](docs/firebase-setup.md), đặt file **thật** `android/app/google-services.json` và build:

```powershell
flutter run --dart-define=ATTENDANCE_BASE_URL=https://<PROJECT_ID>.web.app
```

Web là cùng codebase, phục vụ trang sinh viên nhận link:
```powershell
flutter build web --dart-define-from-file=config/firebase.local.json
npx firebase deploy --only hosting --project <PROJECT_ID>
```

Không commit service account, OAuth secrets, keystore, khóa mô hình hay thông tin sinh viên thật. Không có mock account/seed data trong production. `config/firebase.example.json` chỉ là template, không dùng nguyên mẫu để chạy.

## Markbook đầu vào
ODS/XLSX có hàng header: `class_code, subject, student_id, student_name, email`. Mỗi dòng một sinh viên trong một lớp. Có thể chứa nhiều lớp và nhiều sheet; mỗi sheet dùng cùng header. Dữ liệu sai/trùng báo trước xác nhận. Import lại cùng học kỳ/lớp/môn giữ lịch, sinh viên cũ và audit; thêm A cho sinh viên mới ở meeting đã chốt.

Tạo fixture tổng hợp để kiểm thử, không nạp tự động vào app:
```powershell
dart run tool/create_fixture.dart
adb push test/fixtures/lab3-fixture.xlsx /sdcard/Download/lab3-fixture.xlsx
adb push test/fixtures/invalid.xlsx /sdcard/Download/invalid.xlsx
```
Muốn thử luồng sinh viên thật, thay email fixture bằng email của tài khoản test riêng trước import. `example.test` là địa chỉ giả có chủ đích.

## Kiểm thử

```powershell
flutter test --reporter expanded
npm ci
npm run test:rules
cd e2e_test
uv sync
# Thiết lập ARTEMIS_BASE_URL, ANDROID_SERIAL, E2E_GOOGLE_ACCOUNT
uv run pytest -m 'not exploratory' -v
uv run python summarize.py
```
ARTEMIS pin `google/artemis@351ca8422f7b5b54e80a9c1ce03a222e02415b6b`. SDK `ArtemisClient.run` có structured observations và value assertions, tự lặp 3 lần. Thiếu cấu hình → SKIP, không báo PASS. Hướng dẫn đầy đủ và exploratory: [test-plan](docs/test-plan.md).

## Bản đồ bài nộp

| Thành phần | Vị trí |
|---|---|
| Truy vết màn hình/flow/component | docs/design-traceability.md |
| Đặc tả workflow + state machine | docs/workflows.md |
| Kiến trúc và sequence | docs/architecture.md |
| Analytics plan | docs/analytics-plan.md |
| Test plan + SDK suite | docs/test-plan.md, e2e_test/ |
| AI review output và quyết định | docs/code-review-raw.md, docs/code-review.md |
| Report 10 trang | report/Lab03_SE190145.pdf |
| Slide 15 trang | slides/Lab03_SE190145_slides.pdf |
| Slide editable | slides/Lab03_SE190145_slides.pptx |
| Kịch bản video 5–10 phút | docs/demo-script.md |
| Bằng chứng thật / pending checklist | evidence/, docs/submission-status.md |

## Quyết định và giới hạn
Local JSON xác nhận lưu offline; Firestore sync bằng revision và giữ local khi conflict. Workspace cloud giới hạn payload 800 KB (một document); vượt giới hạn báo rõ và vẫn giữ local. Cần phân mảnh theo lớp/meeting cho quy mô lớn. Drive dùng `drive.file` và phát hiện version conflict; nguồn mở qua document picker Android. Link tối đa 450 sinh viên do giới hạn batch. Link đang mở cần mạng để drain/stop trước chốt. Firebase Storage cần Blaze; chưa bật billing.

File JSON export có schema version 1 được mô tả trong mã; chưa có contract của extension desktop trong tài liệu nên cần đối chiếu với extension thực tế. Chưa có Figma/handoff/ảnh Lab 2 liên kết trong DESIGN.md để đối chiếu pixel hoặc cập nhật Figma. Các khác biệt ghi trong traceability.

## AI disclosure
OpenAI Codex: đọc yêu cầu, lập kiến trúc, sinh và sửa mã, chạy kiểm thử, local AI review, viết tài liệu và slide. Google ARTEMIS: suite chuẩn bị để chạy, **chưa có phiên thực thi thật**. Không dùng ảnh Console hay kết quả E2E giả.

Nguồn API: [Flutter architecture](https://docs.flutter.dev/app-architecture), [FlutterFire setup](https://firebase.google.com/docs/flutter/setup), [ARTEMIS SDK](https://github.com/google/artemis/tree/351ca8422f7b5b54e80a9c1ce03a222e02415b6b/packages/artemis-client), [Google Sign-In](https://pub.dev/packages/google_sign_in), [Storage billing](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).
