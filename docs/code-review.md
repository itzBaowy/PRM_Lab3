# Quyết định AI code review

Tool: OpenAI Codex. Scope: local diff `62b842e`, tests `8df1606`; nguyên văn tại `docs/code-review-raw.md`. Người dùng yêu cầu đưa thẳng main, vì vậy chưa có PR review bên ngoài. Không khai báo đây là review Copilot/CodeRabbit hoặc PR đã merge.

| ID | File:line (sau sửa) | Nhóm | Phát hiện / quyết định | Lý do và kiểm chứng | Fix |
|---|---|---|---|---|---|
| CR-01 | lib/widgets/frozen_week_table.dart:7 | Bug/UI | Accepted: giữ slot ngoài cuộn ngang, đồng bộ offset | DESIGN S02; widget test kiểm tra tọa độ slot không đổi | [d45c9fa](https://github.com/itzBaowy/PRM_Lab3/commit/d45c9fa) |
| CR-02 | lib/viewmodels/feature_vms.dart:24 | Data integrity | Accepted: invalidate preview khi đổi form | Preview không được khác dữ liệu xác nhận | [2c35084](https://github.com/itzBaowy/PRM_Lab3/commit/2c35084) |
| CR-03 | lib/viewmodels/workspace_vm.dart:181 | Concurrency | Accepted: serialize create/attach, stop nếu local save fail | Một phiên, không mất P/A khi thao tác đồng thời | [78ae243](https://github.com/itzBaowy/PRM_Lab3/commit/78ae243) |
| CR-04 | lib/viewmodels/workspace_vm.dart:235 | Performance/state | Modified: poll khi có việc, không ghi submissions cũ, timeout | Giảm ghi file và revision giả; chưa đo production latency | [a3d2c27](https://github.com/itzBaowy/PRM_Lab3/commit/a3d2c27) |
| CR-05 | lib/viewmodels/session_vm.dart:7 | Architecture/lifecycle | Accepted: cleanup và route lookup vào VM | Lab §5, tránh BuildContext sau await | [1cf0243](https://github.com/itzBaowy/PRM_Lab3/commit/1cf0243) |
| CR-06 | firebase/firestore.rules:32 | Security | Accepted: secret read owner-only; emulator coverage | 8 test thật owner/member/expiry/stop/Storage | [cd02d61](https://github.com/itzBaowy/PRM_Lab3/commit/cd02d61) |
| CR-07 | test/widget_test.dart:1 | Test gap | Accepted: narrow viewport, long name, reason/cancel, scroll | 360/412 dp render và interaction tests | [3b5cfa6](https://github.com/itzBaowy/PRM_Lab3/commit/3b5cfa6) |
| CR-08 | android/app/build.gradle.kts:8 | Integration | Accepted: plugins conditional on real config; incremental off trên Windows | APK debug build pass; không tạo config giả | [5ec4562](https://github.com/itzBaowy/PRM_Lab3/commit/5ec4562) |

## Giới hạn review
Local AI review không độc lập với tác giả AI và không thay chạy Google Auth/Drive/FCM trên thiết bị. Cần PR review thật theo handout nếu giảng viên không chấp nhận hình thức local. Mọi fix có commit riêng; không tạo phát hiện giả để đủ số lượng. Các phát hiện CR-03/04 đã sửa cấu trúc và cần E2E concurrency/offline với cloud thật để kiểm chứng toàn bộ.

## AI disclosure
Codex dùng để lập kế hoạch, implementation, review, tests và tài liệu. ARTEMIS suite viết theo SDK thật tại commit pin; chưa chạy agent/test device. Không có kết quả benchmark, pass-rate hay screenshots cloud được dựng.
