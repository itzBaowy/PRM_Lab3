"""Rebuild the report from actual project status. Requires reportlab and a Vietnamese font."""
from pathlib import Path
from xml.sax.saxutils import escape
import os
from reportlab.pdfgen import canvas
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, Image
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_LEFT

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'report/Lab03_SE190145.pdf'
OUT.parent.mkdir(exist_ok=True)
font_root = Path(os.environ.get('REPORT_FONT_DIR', 'C:/Windows/Fonts'))
pdfmetrics.registerFont(TTFont('Report', str(font_root/'arial.ttf')))
pdfmetrics.registerFont(TTFont('ReportBold', str(font_root/'arialbd.ttf')))
PRIMARY = colors.HexColor('#C93C13')
TEXT = colors.HexColor('#243047')
styles = {
    'h1': ParagraphStyle('h1',fontName='ReportBold',fontSize=23,leading=30,textColor=PRIMARY,spaceAfter=18),
    'h2': ParagraphStyle('h2',fontName='ReportBold',fontSize=13,leading=19,textColor=TEXT,spaceBefore=12,spaceAfter=7),
    'body': ParagraphStyle('body',fontName='Report',fontSize=10.5,leading=16,textColor=TEXT,spaceAfter=9),
    'small': ParagraphStyle('small',fontName='Report',fontSize=8.5,leading=12,textColor=colors.HexColor('#667085'),spaceAfter=8),
}
story=[]
def p(text,style='body'):
    story.append(Paragraph(escape(text).replace('\n','<br/>'),styles[style]))
def heading(n,title):
    if story: story.append(PageBreak())
    p(f'{n:02d}  {title}','h1')
def table(headers,rows,widths):
    data=[[Paragraph(escape(str(v)),styles['small']) for v in row] for row in [headers]+rows]
    item=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT')
    item.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#FFF0E8')),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,0),1,PRIMARY),('LINEBELOW',(0,1),(-1,-1),.3,colors.HexColor('#D9DEE7')),('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7)]))
    story.append(item); story.append(Spacer(1,10))
def screenshot(path,width=170):
    from PIL import Image as PILImage
    w,h=PILImage.open(ROOT/path).size
    story.append(Image(str(ROOT/path),width=width,height=width*h/w,hAlign='LEFT'))

heading(1,'FAP Attendance Mobile')
p('PRM393 - Lab 3: Cloud-Enabled Mobile App','h2')
p('Nhóm 3\nKhưu Gia Bảo - SE190145\nNgày lập: 11/11/2026')
p('Bản triển khai và hồ sơ kiểm chứng','h2')
p('Ứng dụng hỗ trợ giảng viên FPT nhận danh sách lớp, lập lịch, ghi nhận điểm danh và bàn giao kết quả trên Android. Đề tài giữ nguyên DESIGN.md của Lab 2. Lab 3 bổ sung xác thực Google và các dịch vụ Firebase, đo lường, kiểm thử tự động và rà soát mã.')
p('Proto-persona P01 là giả định thiết kế: giảng viên quản lý nhiều lớp, cần thao tác nhanh trên điện thoại và có thể gặp mạng yếu. Thành công được đánh giá bằng chọn đúng lớp/buổi, ghi P/A không mất dữ liệu khi chuyển mode, chốt có xác nhận, sửa có lý do và xác định được dữ liệu đã lưu ở đâu. Không có số liệu nghiên cứu người dùng hoặc ngưỡng thời gian được cung cấp nên báo cáo không tự tạo các con số đó.')
p('Trạng thái quan trọng','h2')
p('Mã nguồn đã được xây dựng, unit/widget và security emulator tests đã chạy. APK Android debug và web build thành công. Nhóm chưa có Firebase project và chưa có thiết bị/ARTEMIS daemon/model key; sáu dịch vụ cloud, OAuth Drive, E2E trên Android và demo video vẫn cần kiểm chứng thật. Đây chưa phải bản xác nhận đạt toàn bộ rubric.')
p('Repository: https://github.com/itzBaowy/PRM_Lab3\nNhánh bàn giao: main, theo yêu cầu người dùng.','small')
p('Nguồn: DESIGN.md; Lab 3 requirement 18 trang; Preparation Guide 25 trang; Workflow 15 trang. Nội dung yêu cầu dùng Google ARTEMIS dù tên file còn có Patrol.','small')

heading(2,'Ba workflow nghiệp vụ')
p('Mỗi workflow được mô tả bằng actor, trigger, precondition, bước xử lý, điểm quyết định, kết quả và ngoại lệ. Đăng nhập là điều kiện hỗ trợ; mở màn hình không được tính là kết quả nghiệp vụ.')
table(['Workflow','Kết quả và nhánh cần kiểm tra'],[
['WF-01 Tiếp nhận danh sách và lập lịch','Giảng viên chọn ODS/XLSX, hệ thống kiểm tra và preview, xác nhận merge roster, cấu hình lịch. Kết quả: lớp có danh sách và meeting. Sai file giữ form; hủy không đổi dữ liệu; lớp active/closed khóa sửa lịch.'],
['WF-02 Ghi nhận và chốt buổi học','Giảng viên mở meeting hôm nay, chọn link/manual; sinh viên xác nhận qua link hoặc giảng viên ghi P/A. Chốt có thống kê, unknown thành A. Duplicate không tăng đếm; link không ghi đè manual; hủy chốt giữ phiên.'],
['WF-03 Điều chỉnh và bàn giao','Giảng viên xem lịch sử, sửa có lý do mới và audit, chọn một meeting đã chốt để xuất JSON/CSV. Local save và cloud upload có trạng thái riêng. Lý do trắng bị chặn, cancel không báo thành công, conflict giữ dữ liệu.']],[145,355])
p('Vòng đời meeting','h2')
p('upcoming → active khi bắt đầu đúng ngày và workspace không có phiên khác. active → closed khi xác nhận chốt. Khi mở/kiểm tra app sang ngày mới, meeting cũ được hoàn tất, giữ kết quả đã có và bổ sung A cho ô còn thiếu. Closed không mở lại; mọi điều chỉnh qua audit.')
p('Ràng buộc P/A','h2')
p('Mỗi sinh viên có tối đa một kết quả cho mỗi meeting. Tổng Present + Absent + Chưa ghi nhận bằng sĩ số. Tỷ lệ vắng chia cho tổng số buổi đã lên lịch, kể cả tương lai. Dừng link chỉ dừng nhận; Back và chuyển mode không tự chốt.')
p('Truy vết chi tiết: docs/workflows.md, docs/test-plan.md; implementation: AttendanceEngine; tests BR01–BR16.','small')

heading(3,'Truy vết thiết kế và giao diện')
table(['Màn','Route / hành vi'],[['S01 / S03','/workspace, /import: email nhận diện, nguồn markbook, preview'],['S02 / S05','/home, /schedule: hai mode danh sách/lịch, slot cố định, nghỉ/bù'],['S04 / S06','/attendance, /link: P/A chung, link/code/copy/share/stop'],['S07 / S08','/student, /history: tỷ lệ vắng, audit và meeting của đúng lớp'],['S09 / S10','/export, /drive: local file, Storage/Drive progress/conflict'],['Bổ sung','/signin, /profile và student web: bắt buộc theo Lab 3']],[105,395])
p('Sai khác có giải thích','h2')
p('Lab 2 lưu local và tùy chọn Drive. Lab 3 yêu cầu Firebase, vì vậy thêm Firestore cho dữ liệu người dùng và Cloud Storage cho file tạo ra. Email S01 không dùng làm bằng chứng quyền sở hữu. Hai tab cấp cao vẫn là Lịch tuần & lớp và Drive; Profile mở từ app bar.')
p('Không có Figma/handoff/ảnh gốc được DESIGN.md liên kết trong thư mục được giao. Ứng dụng dựa trên đặc tả văn bản. Chưa thể tuyên bố pixel parity hoặc cập nhật Figma; nhóm phải cung cấp bản gốc và ghép ảnh đối chiếu trước khi nộp.')
screenshot(Path('evidence/ui/attendance-360.png'),115)
p('Ảnh: Flutter widget golden 360 dp, dữ liệu tổng hợp. Chứng minh render kiểm thử, không phải ảnh Firebase/thiết bị thật.','small')

heading(4,'Kiến trúc MVVM và design system')
p('View → ViewModel → services/domain → local/Firebase/Drive. Provider inject services; widgets không gọi SDK. Composition root app.dart khởi tạo adapter. BaseVm quản lý loading/empty/error/data, busy, message và error. Các màn có dữ liệu đã tải dùng WorkspaceVm chung để giữ ngữ cảnh lớp, meeting, tuần và tìm kiếm.')
table(['Thành phần','Trách nhiệm'],[['AttendanceEngine','Lịch, start/mark/close/rollover, merge roster, audit, absence rate'],['WorkspaceVm','Clone dữ liệu, validate, ghi local, rồi publish state; serialize command và sync revision'],['Import/Link/Export/Drive/Profile VMs','Điều phối tác vụ, progress, retry/cancel và state tương ứng'],['Services','Adapter Auth, Firestore, Storage, FCM, RC, telemetry, Drive, parser, file I/O']],[145,355])
p('Trình tự ghi dữ liệu','h2')
p('Lựa chọn của giảng viên tạo bản sao workspace, áp dụng rule, lưu JSON rồi thay state. Lỗi ghi không thay kết quả đã lưu. Firestore transaction so cloudRevision với revision remote; khác nhau thì báo conflict và giữ bản local. Trước chốt link đang nhận, service khóa phiên trên server rồi drain các submission đã commit.')
p('Theme và component','h2')
p('Primary #C93C13, background #FFF7F3, text #243047; Roboto có tiếng Việt. Spacing 4/8/12/16/24/32, radius 8/12/16, touch tối thiểu 48 dp. AppButton/AppField/AppCard/AppPage/StatePanel/AppNavigation/StudentRow/MeetingCell được tái sử dụng. Segmented P/A loại trừ nhau và có trạng thái chưa chọn; status có nhãn văn bản ngoài màu.')
p('Kiểm chứng: unit test lỗi lưu; widget test 360/412 dp, tên dài và cột lịch cố định. Sơ đồ layer/sequence: docs/architecture.md.','small')

heading(5,'Firebase Authentication và Storage')
p('Authentication','h2')
p('GoogleSignIn.authenticate trên Android cung cấp ID token cho Firebase Auth. Web dùng signInWithPopup. AuthVm theo dõi authStateChanges, routes signed-out vào sign-in, signed-in vào workspace. Cancel picker có thông báo. SessionVm xóa cache workspace, thông báo và metadata Drive khi sign-out; chặn sign-out khi link vẫn mở.')
p('Storage','h2')
p('ExportService chỉ tạo file từ một meeting closed đủ P/A. JSON chứa schema, lớp/môn/học kỳ/ngày/slot và roster; CSV quote đúng và chống công thức bảng tính. Người dùng chọn local save hoặc share; cancel không báo saved. UploadTask cung cấp progress, lưu reports/{uid}/{filename}, trả download URL. Rules owner-only, MIME JSON/CSV, giới hạn 10 MB.')
p('Failure handling','h2')
p('Không mạng, thiếu quyền hoặc cấu hình sai được ViewModel chuyển thành lỗi đọc được và retry. Lỗi upload giữ generated file và bản local. Analytics không được làm thất bại thao tác đã lưu. Không hiển thị stack trace hay ghi email vào analytics.')
table(['Bằng chứng','Hiện trạng'],[['Build và code','Android/web build pass; AuthService và CloudFileService có adapter thật'],['Security','Emulator kiểm tra cross-user read/write bị từ chối'],['Cloud Console','Chưa có project/config/Users/file list thật'],['Billing','Cloud Storage hiện yêu cầu Blaze. Nhóm quyết định billing hoặc xin phương án thay thế với giảng viên']],[145,355])
p('Nguồn: firebase.google.com/docs/flutter/setup; firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024. Hướng dẫn cấu hình: docs/firebase-setup.md.','small')

heading(6,'FCM và Analytics')
p('Cloud Messaging','h2')
p('Profile xin notification permission Android 13+. Token đăng ký nằm dưới users/{uid}/devices. Service xử lý foreground, background entry point, initial message và tap. Inbox lưu từng message riêng theo UID để giảm race giữa isolates. classId/meetingId chỉ mở meeting có trong workspace. Với notification payload khi app bị kill, Android có thể chỉ giao message cho app lúc tap; server inbox cho các notification chưa mở chưa triển khai.')
p('Analytics event plan','h2')
table(['Nhóm câu hỏi','Event / params an toàn'],[['Auth','login(method), logout; Firebase UID, không email'],['Nhập và lịch','import_markbook(format,class_count,student_count), configure_schedule(meeting_count)'],['Tìm và detail','search(query_length,result_count), view_class/view_student/view_history(screen_name)'],['Điểm danh','attendance_mark(status,mode), attendance_close(present,absent), attendance_edit(before,after)'],['Bàn giao','export_report(format,byte_count), upload_report(byte_count,destination), create_attendance_link(code_enabled)']],[145,355])
p('Search có thể là tên/MSSV nên không gửi nội dung truy vấn. Reason của audit và roster chỉ nằm trong workspace thuộc owner. Telemetry nonfatal cũng loại thông tin dòng import khỏi message gửi server.')
p('Bằng chứng còn cần','h2')
p('Chụp ba trạng thái FCM, native permission, inbox và navigation trên thiết bị. Bật Analytics debug mode, kích hoạt toàn bộ 14 event và chụp DebugView params. Test ARTEMIS TC01/TC13 còn yêu cầu kiểm event trong Logcat, không chỉ dựa lời agent.')
p('Nguồn mã: notification_service.dart, telemetry_service.dart; kế hoạch trước instrumentation: docs/analytics-plan.md. Chưa có Console evidence.','small')

heading(7,'Crashlytics, Remote Config và Drive')
p('Crashlytics','h2')
p('Bootstrap gắn Flutter fatal và PlatformDispatcher errors. Handled error đi qua BaseVm và telemetry.error; ví dụ thực là import tệp hỏng. Gắn Firebase UID, app_area và operation; giữ dữ liệu nhập để retry. Nút test crash ở Profile có xác nhận riêng, không nằm trong flow bình thường. Cần chạy rồi khởi động lại app để kiểm dashboard, không giả định SDK call nghĩa là Console đã nhận.')
p('Remote Config','h2')
table(['Tham số','Default / tác động nhìn thấy'],[['attendance_link_enabled','true; false vô hiệu tạo link ở S04/S06, manual vẫn dùng được'],['absence_warning_percent','20; thay ngưỡng cảnh báo tỷ lệ vắng trên S07']],[210,290])
p('ConfigService set defaults, fetchAndActivate với timeout 10 giây và minimum interval 1 phút; clamp threshold 1–100. Fetch lỗi giữ config hiện tại/default, báo lỗi. Evidence phải gồm Console và trước/sau hành vi trên cùng build.')
p('Drive và local-first','h2')
p('Drive là đích tùy chọn của Lab 2, tách Cloud Storage bắt buộc. Scope drive.file chỉ truy cập file đã được cấp quyền; Android document picker hỗ trợ chọn nguồn Drive. Upload ghi file ID/version/hash theo UID, file không đổi không chủ ý tạo bản sao. Version khác báo conflict, giữ bản local. Kết nối không tự tạo lớp hoặc xác thực email S01.')
p('Giới hạn cần test thật','h2')
p('Chưa kiểm OAuth consent, token expiry, API permission, FCM foreground/background/terminated và cloud conflict giữa hai thiết bị. Docs/firebase-setup.md nêu cấu hình, evidence/README.md nêu ảnh phải thu. Không ghi “đã tích hợp thành công trên cloud” khi thiếu các bằng chứng này.')

heading(8,'Kiểm thử và độ tin cậy')
table(['Tầng','Kết quả quan sát'],[['Domain / import / export / VM','29 test pass ở lần chạy ban đầu: invariant P/A, duplicate, reason, finalize, schedule, merge, CSV, local failure, conflict'],['Widget','5 test pass: roster 360/412, reason/cancel, frozen slots, calendar overflow; PNG ở evidence/ui'],['Security Emulator','8 test pass: owner revision, verified member, private secret, visit/code/duplicate, expired visit, stop, batch, Storage isolation'],['Build','Android debug APK và Flutter web build thành công'],['ARTEMIS','54 lượt regression được collect nhưng skipped do thiếu hạ tầng. 3 exploratory instances deselected trong preflight. Không có pass-rate device']],[140,360])
p('ARTEMIS test design','h2')
p('18 ca cover ba workflow với main/alternative/error, auth, search, top tabs, detail, export/upload, RC, FCM và sign-out. Mỗi pytest function gửi một instruction qua ArtemisClient, bắt đầu từ precondition độc lập, trả JSON observations và assert từng giá trị. Fixture tự chạy 3 lần. Native picker/quick settings/notification được nêu cụ thể. SDK pin commit 351ca8422f7b5b54e80a9c1ce03a222e02415b6b.')
p('Không tin trạng thái agent đơn lẻ','h2')
p('result.succeeded chỉ là điều kiện đầu. Thiếu output có cấu trúc hoặc sai count/status/percent đều fail. Logcat event là assertion bổ sung ở auth/upload. Mỗi run phải có trace ID, ảnh/replay, thời gian và summary. Dưới 3/3 phân loại flaky và ghi fix; không bỏ assertion để lấy pass.')
p('Exploratory Pro 15–30 phút chưa thực hiện. Nhóm cần ghi vấn đề thật cùng reproduction; không tạo issue giả khi không quan sát. Kết quả chi tiết và lệnh: docs/test-plan.md, evidence/validation, evidence/artemis/results.md.','small')

heading(9,'AI code review và quyết định')
p('Codex thực hiện local review trên diff triển khai. Người dùng yêu cầu đẩy thẳng main nên chưa có PR review bên ngoài. Tám findings thật được lưu nguyên văn; các commit dưới đây sửa từng phát hiện. Cần external PR review nếu giảng viên không chấp thuận local review.')
table(['ID / nhóm','Quyết định và commit'],[['CR-01 UI','Accepted: freeze slot + đồng bộ scroll. d45c9fa'],['CR-02 data','Accepted: invalidate preview khi đổi form. 2c35084'],['CR-03 concurrency','Accepted: serialize create/attach; stop khi local fail. 78ae243'],['CR-04 performance','Modified: poll có điều kiện, không ghi kết quả cũ, timeout. a3d2c27'],['CR-05 architecture','Accepted: cleanup/routing vào VM, bỏ context sau await. 1cf0243'],['CR-06 security','Accepted: secret owner-only, thêm emulator tests. cd02d61'],['CR-07 test gap','Accepted: 360/412, reason/cancel, fixed calendar. 3b5cfa6'],['CR-08 integration','Accepted: Android Firebase plugins + sửa Kotlin cache khác ổ. 5ec4562']],[145,355])
p('Lý do sửa dựa yêu cầu','h2')
p('Các quyết định liên hệ trực tiếp DESIGN S02/S03/S04 hoặc Lab §5/§6: không mất ngữ cảnh, dữ liệu xác nhận phải khớp preview, SDK không nằm ở widget, quyền thuộc owner. Test chứng minh domain/VM/render/rules; vẫn cần E2E cloud cho race, token và platform lifecycle.')
p('Disclosure','h2')
p('OpenAI Codex được dùng cho phân tích, code generation, sửa lỗi, tests, local review, báo cáo và slide. ARTEMIS được chuẩn bị nhưng chưa chạy thực. Không sử dụng kết quả Console/E2E dựng sẵn. Nhóm phải hiểu và giải thích code khi giảng viên kiểm tra.')
p('File/line, lý do và link commit: docs/code-review.md. Lịch sử làm việc là một ngày thực, không tạo commit giả nhiều ngày.','small')

heading(10,'Bàn giao và phần việc còn lại')
p('Những gì đã có','h2')
p('Repository chứa ứng dụng Flutter, rules, theme/components, unit/widget/security tests, ARTEMIS suite, workflow/architecture/analytics/test/review docs, report và slide. Native APK và web compiler đã chạy; UI golden và log được lưu rõ nguồn. Nhánh main là lựa chọn của người dùng, không suy ra đã deploy.')
p('Các bước để đủ bài nộp','h2')
for t in [
'1. Tạo Firebase project của nhóm, thêm SHA/OAuth, bật Auth/Firestore/Storage, deploy rules và Hosting. Quyết định billing Blaze trước khi bật Storage.',
'2. Chạy Android thật với dedicated account; xác minh student link hai tài khoản, import thực tế, offline, Drive và exports. Chụp đủ sáu Firebase Console evidence.',
'3. Chạy ARTEMIS 3 lượt/ca và Pro 15–30 phút. Ghi trace, screenshot, pass-rate, flaky root cause và fixes.',
'4. Bổ sung Figma/handoff, đối chiếu ảnh app và cập nhật mọi deviation. Thực hiện PR review nếu được yêu cầu.',
'5. Quay video 5–10 phút theo docs/demo-script.md, cập nhật URL và dựng lại report/slide với evidence mới. Kiểm tra quyền truy cập bằng incognito.']:
    p(t)
p('Hạn chế kỹ thuật đã biết','h2')
p('Workspace cloud một document giới hạn 800 KB; link batch tối đa 450 sinh viên. Drive scope không đọc toàn bộ Drive. Notification chưa mở khi app bị kill cần server inbox để lưu đầy đủ. Contract extension desktop chưa được cung cấp nên JSON schema cần đối chiếu. Không có phép đo latency hay user study để tuyên bố hiệu năng/thành công người dùng.')
p('Bài học','h2')
p('Tách saved-local và synced giúp phản hồi trung thực. Preview cần invalidation khi form đổi. Cloud link phải được khóa/drain trước finalize. Test negative security là phần thiết yếu; permission-denied trong log của ca từ chối không phải thất bại. Bằng chứng là điều kiện của tuyên bố, không phải phần trang trí bài nộp.')
p('Nguồn bổ sung và toàn bộ liên kết: README.md. Tài liệu nguồn gốc được giữ nguyên trong repository.','small')

def footer(c,doc):
    c.setStrokeColor(colors.HexColor('#D9DEE7'));c.line(48,42,547,42)
    c.setFont('Report',8);c.setFillColor(colors.HexColor('#667085'))
    c.drawString(48,28,'FAP Attendance Mobile · Nhóm 3 · SE190145 · Bản triển khai, chờ evidence cloud')
    c.drawRightString(547,28,str(doc.page))

doc=SimpleDocTemplate(str(OUT),pagesize=(595.28,841.89),rightMargin=48,leftMargin=48,topMargin=42,bottomMargin=56,title='Lab 3 - FAP Attendance Mobile - SE190145',author='Nhóm 3 - Khưu Gia Bảo')
doc.build(story,onFirstPage=footer,onLaterPages=footer)
print(OUT)
