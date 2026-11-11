import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

// Supplied Codex artifact runtime; set these when rebuilding on another machine.
const runtime = process.env.RUNTIME_NODE_MODULES;
if (!runtime) throw new Error('Set RUNTIME_NODE_MODULES to the supplied artifact runtime node_modules.');
const { Presentation, PresentationFile } = await import(pathToFileURL(path.join(runtime, '@oai/artifact-tool/dist/artifact_tool.mjs')).href);
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1')), '..');
const staging = path.join(root, 'tmp/slides');
await fs.mkdir(staging, {recursive:true});
await fs.mkdir(path.join(root,'slides'), {recursive:true});
const deck = Presentation.create({slideSize:{width:1280,height:720}});
const color={primary:'#C93C13',text:'#243047',muted:'#667085',bg:'#FFF7F3'};
function textbox(slide,text,left,top,width,height,size=28,bold=false,fill=color.text){
  const shape=slide.shapes.add({geometry:'textbox',position:{left,top,width,height},fill:'none',line:{fill:'none',width:0}});
  shape.text=text;shape.text.style={fontFamily:'Arial',fontSize:size,bold,color:fill};shape.text.insets=0;
  return shape;
}
function slide(title,points,{source,footnote,image,diagram}={}){
  const s=deck.slides.add();s.background.fill=color.bg;
  textbox(s,title,72,54,1136,92,44,true,color.primary);
  const width=image?760:1136;
  points.forEach((point,i)=>textbox(s,point,72,176+i*103,width,92,28));
  if(image){
    const bytes=image.bytes;
    s.images.add({blob:bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),contentType:'image/png',alt:'Flutter widget test screenshot with synthetic roster',fit:'contain',position:{left:930,top:155,width:235,height:495}});
  }
  if(diagram){
    const labels=['View\nScreens / Widgets','ViewModel\nProvider + state','Services\nDomain + adapters','Data\nLocal / Firebase / Drive'];
    labels.forEach((label,i)=>{
      const box=s.shapes.add({geometry:'rect',position:{left:72+i*300,top:230,width:250,height:130},fill:'#FFFFFF',line:{fill:color.primary,width:2}});
      box.text=label;box.text.style={fontFamily:'Arial',fontSize:26,color:color.text};box.text.insets=16;
      if(i<3)s.shapes.add({geometry:'rightArrow',position:{left:335+i*300,top:275,width:28,height:32},fill:color.primary,line:{fill:'none',width:0}});
    });
    textbox(s,'View không gọi SDK. Business rules nằm trong AttendanceEngine.\nClone dữ liệu, ghi local thành công, rồi mới cập nhật trạng thái hiển thị.',72,415,1136,120,28);
  }
  textbox(s,footnote??source??'Nhóm 3 · Khưu Gia Bảo · SE190145',72,657,1080,40,18,false,color.muted);
  textbox(s,String(deck.slides.items.length),1170,657,40,40,18,false,color.muted);
  s.speakerNotes.text=`${source??'Nguồn: mã nguồn và tài liệu trong repository.'}\nTrạng thái: đây là bản triển khai, chưa có Firebase project/Console evidence hoặc ARTEMIS device runs.\nAI disclosure: OpenAI Codex dùng để tạo và kiểm tra tài liệu. Không dùng evidence dựng sẵn.`;
  return s;
}

const cover=deck.slides.add();cover.background.fill=color.bg;
textbox(cover,'FAP Attendance\nMobile',72,140,1136,210,72,true,color.primary);
textbox(cover,'PRM393 Lab 3 · Flutter và Firebase',76,390,1100,70,34);
textbox(cover,'Nhóm 3 · Khưu Gia Bảo · SE190145',76,488,1100,60,28);
textbox(cover,'Bản triển khai ngày 11/11/2026. Chờ cấu hình và bằng chứng cloud thật.',76,617,1100,50,22,false,color.muted);
cover.speakerNotes.text='Nguồn: DESIGN.md và ba PDF hướng dẫn của người dùng. Persona P01 là giả định, chưa có user study. AI: Codex. Repository https://github.com/itzBaowy/PRM_Lab3';

slide('Giảng viên và ba workflow',[
  'P01: giảng viên quản lý nhiều lớp trên điện thoại, có thể gặp mạng yếu. Đây là proto-persona giả định.',
  'WF-01: tiếp nhận markbook và lập lịch. Kết quả là roster và meeting sẵn sàng để điểm danh.',
  'WF-02: ghi nhận và chốt buổi học. WF-03: sửa có audit và bàn giao kết quả.',
  'Tiêu chí: đúng lớp/buổi, không mất P/A, chốt có xác nhận, biết dữ liệu đã lưu ở đâu.'
],{source:'Nguồn: DESIGN.md; docs/workflows.md. Chưa có số liệu user study.'});

slide('Đặc tả Lab 2 và màn hình Flutter',[
  'DESIGN.md: một roster, hai mode Qua link / Thủ công, số lượng P/A/Chưa ghi nhận dùng chung.',
  'Flutter: tên dài xuống dòng, điều khiển có nhãn, trạng thái lưu local tách đồng bộ.',
  'Ảnh bên phải là widget golden 360 dp với dữ liệu tổng hợp. Kiểm tra thêm ở 412 dp.',
  'Chưa có Figma/handoff gốc để đặt ảnh đối chiếu. Không tuyên bố pixel parity.'
],{source:'docs/design-traceability.md; evidence/ui/attendance-360.png',image:{bytes:await fs.readFile(path.join(root,'evidence/ui/attendance-360.png'))}});

slide('Kiến trúc MVVM',[],{source:'docs/architecture.md; lib/app.dart; lib/viewmodels/; lib/services/',diagram:true});

slide('Design system trong code',[
  'ThemeData: primary #C93C13, nền #FFF7F3, chữ #243047. Font Roboto hỗ trợ tiếng Việt.',
  'Spacing 4 / 8 / 12 / 16 / 24 / 32. Radius 8 / 12 / 16. Control có vùng chạm tối thiểu 48 dp.',
  'AppButton, AppField, AppCard, StatePanel, StudentRow và MeetingCell được tái sử dụng.',
  'FrozenWeekTable giữ nhãn khung giờ cố định, đồng bộ cuộn ngang và chiều cao từng hàng.'
],{source:'lib/theme/app_theme.dart; lib/widgets/; test/widget_test.dart'});

slide('Firebase Authentication',[
  'Google Sign-In cung cấp token cho Firebase Auth. Auth state quyết định sign-in hay workspace.',
  'Hủy picker có thông báo. Sign-out xóa dữ liệu local, thông báo và metadata Drive theo UID.',
  'Email S01 chỉ nhận diện, không chứng minh quyền sở hữu. Tài khoản Google xác định quyền truy cập.',
  'Chờ cấu hình project, SHA và OAuth; cần ảnh Users Console, signed-in/out và native cancel.'
],{source:'auth_service.dart; auth_vm.dart; session_vm.dart; docs/firebase-setup.md'});

slide('Cloud Storage và kết quả xuất',[
  'Chỉ xuất một lớp / một meeting đã chốt đủ P/A. JSON và CSV lấy trực tiếp dữ liệu đang xem.',
  'Local save, cancel, chia sẻ và cloud upload là các hành động riêng; không báo saved khi hủy.',
  'Upload reports/{uid}/filename, có tiến độ và URL. Rules giới hạn owner, MIME và dung lượng.',
  '8 security tests emulator đã qua. Cloud Storage thật cần project và Blaze; chưa bật billing.'
],{source:'export/file/cloud_file services; firebase/storage.rules; evidence/validation/security-rules.txt'});

slide('Cloud Messaging',[
  'Xin quyền Android 13+, đăng ký token theo UID; xử lý foreground, background và initial message.',
  'Inbox lưu message khi SDK giao callback. Tap mở meeting phù hợp qua classId / meetingId.',
  'Với notification payload khi app bị kill, message có thể chỉ tới app lúc tap. Chưa có server inbox.',
  'Cần quay đủ ba trạng thái FCM, native permission, inbox và deep link trên thiết bị thật.'
],{source:'notification_service.dart; profile VM; docs/firebase-setup.md'});

slide('Analytics có câu hỏi sản phẩm',[
  '14 event bao phủ đăng nhập, import/lịch, search/detail, điểm danh, sửa và xuất/upload.',
  'Dùng login, search và custom snake_case. Params đo count, mode, status, format và destination.',
  'Không gửi tên, email, MSSV, lý do hoặc search text. Chỉ gửi độ dài truy vấn và số kết quả.',
  'Kế hoạch có trước tracking code. Chờ DebugView từng event; ARTEMIS còn kiểm Logcat login/upload.'
],{source:'docs/analytics-plan.md; telemetry_service.dart; e2e_test/conftest.py'});

slide('Crashlytics và lỗi được xử lý',[
  'Nonfatal đi từ luồng lỗi thật, ví dụ import workbook hỏng. Form và dữ liệu đã lưu được giữ lại.',
  'Gắn Firebase UID, app_area và operation. Không đưa nội dung roster hoặc reason vào error message.',
  'Test crash nằm trong Profile và yêu cầu xác nhận riêng. Mở lại app để gửi báo cáo sự cố.',
  'Chờ dashboard có cả nonfatal và crash, cùng UID/custom keys của project nhóm.'
],{source:'main.dart; BaseVm; telemetry_service.dart; evidence/README.md'});

slide('Remote Config thay đổi hành vi',[
  'attendance_link_enabled = true: cho tạo link. Đổi false thì vô hiệu tạo link, manual vẫn hoạt động.',
  'absence_warning_percent = 20: ngưỡng cảnh báo S07. Đổi 40 phải đổi cảnh báo nhìn thấy được.',
  'Có defaults, timeout 10 giây và minimum fetch interval 1 phút. Lỗi fetch giữ config hiện tại.',
  'Cần ảnh Console và trước/sau trên cùng build. Chưa có dữ liệu thực nghiệm cloud.'
],{source:'config_service.dart; firebase/remote-config-defaults.json; TC16'});

slide('ARTEMIS: kiểm giá trị quan sát',[
  '18 ca regression, mỗi ca 3 lượt; một phiên Pro 15–30 phút. SDK pin commit 351ca8422f7b.',
  'Instruction chỉ rõ precondition, steps, expected screen và JSON observations. Pytest so từng giá trị.',
  'Cover cancel/error/offline/native picker, top tabs, detail, export/upload, Remote Config và sign-out.',
  'Preflight: 54 lượt skipped vì thiếu device/daemon/config. Chưa có pass-rate hoặc exploratory evidence.'
],{source:'docs/test-plan.md; e2e_test/; evidence/validation/artemis-preflight.txt'});

slide('AI review và fix có truy vết',[
  '8 findings local từ Codex: UI, data integrity, concurrency, performance, MVVM, security và test gap.',
  'Ví dụ CR-01: slot bị cuộn theo ngày. Fix d45c9fa giữ nhãn và có test tọa độ sau cuộn.',
  'CR-03: link creation có thể race manual save. Fix 78ae243 serialize, rollback khi local thất bại.',
  'Mỗi finding có quyết định, lý do và commit riêng. Chưa có PR review ngoài vì người dùng yêu cầu main.'
],{source:'docs/code-review-raw.md; docs/code-review.md; Git history'});

slide('Kết quả kiểm chứng và giới hạn',[
  '34 Flutter tests pass: 29 domain/import/export/VM và 5 widget. 8 Firebase security tests pass.',
  'Android debug APK và web build thành công. Golden 360/412 dp dùng fixture tổng hợp.',
  'Chưa có Google Auth/Drive/FCM/Analytics/Crashlytics/RC evidence từ project thật.',
  'Giới hạn: snapshot cloud 800 KB, link batch 450 sinh viên; contract extension desktop cần đối chiếu.'
],{source:'evidence/validation/; docs/submission-status.md. Build không đồng nghĩa deploy.'});

slide('Hoàn tất bài nộp và demo',[
  'Tạo project nhóm, cấu hình OAuth/SHA, quyết định billing Storage, deploy rules và Hosting.',
  'Chạy Android + student link, thu đủ Console evidence, ARTEMIS 3/3 và exploratory Pro thật.',
  'Đối chiếu Figma, bổ sung review nếu cần. Quay video 5–10 phút theo ba workflow và Firebase demo.',
  'Cập nhật report/slide bằng evidence thật và kiểm tra quyền xem link. AI dùng: OpenAI Codex.'
],{source:'README.md; docs/demo-script.md; docs/submission-status.md'});

const candidate=path.join(staging,'candidate.pptx');
await (await PresentationFile.exportPptx(deck)).save(candidate);
try {
  const pdf=await deck.export({format:'pdf'});
  await fs.writeFile(path.join(root,'slides/Lab03_SE190145_slides.pdf'),new Uint8Array(await pdf.arrayBuffer()));
} catch (error) {
  // Supplied runtime may lack standard-font PDF modules. Preserve editable PPTX;
  // tool/render_artifacts.py assembles the inspected PNG exports into a PDF.
  console.warn(`PDF renderer fallback required: ${error.message}`);
}
for(let i=0;i<deck.slides.items.length;i++){
  const png=await deck.export({slide:deck.slides.items[i],format:'png',scale:1});
  await fs.writeFile(path.join(staging,`slide-${String(i+1).padStart(2,'0')}.png`),new Uint8Array(await png.arrayBuffer()));
}
await fs.writeFile(path.join(staging,'layout.json'),(await deck.inspect({kind:'slide,textbox,shape,image',maxChars:200000})).ndjson);
const skill=process.env.PRESENTATION_SKILL_DIR;
if(!skill)throw new Error('Set PRESENTATION_SKILL_DIR for final validation.');
const {finalizePresentation}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
const final=path.join(root,'slides/Lab03_SE190145_slides.pptx');
await finalizePresentation({workspaceDir:root,candidatePath:candidate,finalPath:final,pythonExecutable:process.env.RUNTIME_PYTHON,integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-heading-fit'],explicitTotalSlideCount:15,requiredNativeTableOwnerSlides:[],requiredNativeChartOwnerSlides:[],fontPolicy:{basis:'design',families:['Arial']},verifyArtifactToolImport:true,receiptPath:path.join(staging,'validation.json')});
console.log(`Created 15 slides: ${final}`);
