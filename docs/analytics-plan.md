# Kế hoạch Analytics (trước instrumentation)

UID dùng Firebase UID, không email. Không gửi tên, MSSV, email, nội dung search hay lý do chỉnh sửa. `search` chỉ gửi chiều dài và số kết quả để tránh PII.

| Event | Trigger / WF | Parameters (type) | Câu hỏi sản phẩm |
|---|---|---|---|
| login | Google thành công | method:string | Bao nhiêu phiên đăng nhập thành công? |
| logout | Đăng xuất | none | Người dùng kết thúc phiên ở đâu? |
| import_markbook | WF01 xác nhận import | format:string, class_count:int, student_count:int | Bao nhiêu lần nhập tạo workspace dùng được? |
| configure_schedule | WF01 lưu lịch | meeting_count:int | Lịch lớp có được cấu hình trước khi bắt đầu? |
| search | WF02 lọc roster | query_length:int, result_count:int | Bao nhiêu truy vấn không có kết quả? |
| view_class | S04 | screen_name:string | Người dùng mở điểm danh bao nhiêu lần? |
| view_student | S07 | screen_name:string | Bao nhiêu lần cần tra cứu lịch sử cá nhân? |
| view_history | S08 | screen_name:string | Lịch sử lớp có được sử dụng? |
| attendance_mark | WF02 ghi lần đầu | status:string, mode:string | Tỷ lệ ghi nhận thủ công so với link? |
| attendance_close | WF02 chốt | present:int, absent:int | Bao nhiêu buổi được chốt đầy đủ? |
| attendance_edit | WF03 sửa có lý do | before:string, after:string | Bao nhiêu kết quả cần sửa? |
| export_report | WF03 tạo file | format:string, byte_count:int | Bao nhiêu buổi được bàn giao? |
| upload_report | Upload thành công | byte_count:int, destination:string | Xuất file có dẫn đến sao lưu cloud? |
| create_attendance_link | WF02 tạo link | code_enabled:int | Tính năng link được dùng bao nhiêu? |

DebugView: `adb shell setprop debug.firebase.analytics.app vn.edu.fpt.fap_attendance`. Chụp từng event và params vào evidence/firebase/analytics. Chưa có ảnh thì chưa xác nhận Analytics đã lên server.
