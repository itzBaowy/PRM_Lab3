from pathlib import Path
from reportlab.pdfgen import canvas
import fitz

root = Path(__file__).resolve().parents[1]
slides = sorted((root/'tmp/slides').glob('slide-*.png'))
assert len(slides) == 15, 'Expected exactly 15 rendered slides'
# PDF fallback preserves the inspected slide appearance; the PPTX remains editable.
c = canvas.Canvas(str(root/'slides/Lab03_SE190145_slides.pdf'), pagesize=(960,540))
c.setTitle('FAP Attendance Mobile - Lab 3 - SE190145')
c.setAuthor('Nhóm 3 - Khưu Gia Bảo')
for slide in slides:
    c.drawImage(str(slide),0,0,width=960,height=540)
    c.showPage()
c.save()
out = root/'tmp/report-render'
out.mkdir(parents=True,exist_ok=True)
document=fitz.open(root/'report/Lab03_SE190145.pdf')
assert len(document)==10
for i,page in enumerate(document):
    page.get_pixmap(matrix=fitz.Matrix(1,1)).save(out/f'page-{i+1:02}.png')
print('Rendered 10 report pages and assembled 15-page slide PDF.')
