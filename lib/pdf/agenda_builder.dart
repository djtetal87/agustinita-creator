import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../specs.dart';
import '../theme_spec.dart';
import 'fonts.dart';

/// Datos que vienen del formulario de Agenda.
class AgendaJob {
  final String name;
  final String phrase;
  final StyleSpec style;
  final List<PageDef> pages;
  final Uint8List? coverArt; // ilustración generada (portada)
  final Uint8List? characterArt; // personaje (foto → personaje) para la página del nombre
  final Uint8List? interiorArt; // marco ilustrado para todas las páginas interiores
  final bool mirrorBack; // margen de anillos a la derecha en el reverso

  const AgendaJob({
    required this.name,
    required this.phrase,
    required this.style,
    required this.pages,
    this.coverArt,
    this.characterArt,
    this.interiorArt,
    this.mirrorBack = false,
  });
}

class AgendaBuilder {
  final AgendaJob job;
  final PdfFonts f;
  AgendaBuilder(this.job, this.f);

  StyleSpec get s => job.style;
  late final pw.MemoryImage? _interior =
      job.interiorArt == null ? null : pw.MemoryImage(job.interiorArt!);

  // ---------- Interior: hojas carta horizontales, 2 páginas por cara ----------

  Future<Uint8List> buildInterior() async {
    final doc = pw.Document(title: 'Agenda ${job.name} — interior');
    final pages = List<PageDef>.from(job.pages);
    while (pages.length % 4 != 0) {
      pages.add(const PageDef(PageKind.blank));
    }
    for (var i = 0; i < pages.length; i += 4) {
      // cara frontal
      doc.addPage(_sheet(pages[i], pages[i + 1], i + 1, i + 2, ringLeft: true));
      // reverso
      doc.addPage(_sheet(pages[i + 2], pages[i + 3], i + 3, i + 4,
          ringLeft: !job.mirrorBack));
    }
    return doc.save();
  }

  pw.Page _sheet(PageDef a, PageDef b, int na, int nb, {required bool ringLeft}) {
    return pw.Page(
      pageFormat: PdfPageFormat(AgendaSpec.sheetW * mm, AgendaSpec.sheetH * mm),
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Stack(children: [
        pw.Positioned(left: 0, top: 0, child: _half(a, na, ringLeft)),
        pw.Positioned(
            left: AgendaSpec.halfW * mm, top: 0, child: _half(b, nb, ringLeft)),
        // marca de corte central
        pw.Positioned(
          left: AgendaSpec.halfW * mm - 0.15,
          top: 0,
          child: pw.Container(width: 0.3, height: 4 * mm, color: PdfColors.grey600),
        ),
        pw.Positioned(
          left: AgendaSpec.halfW * mm - 0.15,
          top: (AgendaSpec.sheetH - 4) * mm,
          child: pw.Container(width: 0.3, height: 4 * mm, color: PdfColors.grey600),
        ),
      ]),
    );
  }

  /// Una página de 139.7 × 215.9 mm con su margen para los anillos.
  pw.Widget _half(PageDef def, int number, bool ringLeft) {
    final frameLeft = ringLeft
        ? AgendaSpec.ringMargin
        : AgendaSpec.halfW - AgendaSpec.ringMargin - AgendaSpec.frameW;
    final isBlank = def.kind == PageKind.blank;
    return pw.SizedBox(
      width: AgendaSpec.halfW * mm,
      height: AgendaSpec.sheetH * mm,
      child: pw.Stack(children: [
        // guía punteada del anillado (no se imprime fuerte)
        pw.Positioned(
          left: (ringLeft ? AgendaSpec.ringMargin : AgendaSpec.halfW - AgendaSpec.ringMargin) * mm,
          top: 0,
          child: pw.Container(
            width: 0.3,
            height: AgendaSpec.sheetH * mm,
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    left: pw.BorderSide(
                        color: PdfColors.grey400,
                        width: 0.3,
                        style: pw.BorderStyle.dashed))),
          ),
        ),
        if (!isBlank)
          pw.Positioned(
            left: frameLeft * mm,
            top: AgendaSpec.frameTop * mm,
            child: pw.Container(
              width: AgendaSpec.frameW * mm,
              height: AgendaSpec.frameH * mm,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: s.frame, width: 0.8),
                borderRadius: pw.BorderRadius.circular(AgendaSpec.frameRadius * mm),
              ),
              child: pw.Stack(fit: pw.StackFit.expand, children: [
                if (_interior != null)
                  pw.ClipRRect(
                    horizontalRadius: AgendaSpec.frameRadius * mm,
                    verticalRadius: AgendaSpec.frameRadius * mm,
                    child: pw.Image(_interior!, fit: pw.BoxFit.cover),
                  ),
                pw.Padding(
                  // con marco ilustrado el contenido se aleja un poco más del borde
                  padding: pw.EdgeInsets.all((_interior == null ? AgendaSpec.innerPad : AgendaSpec.innerPad + 6) * mm),
                  child: _pageBody(def, number),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  // ---------- Contenido de cada tipo de página ----------

  pw.Widget _title(String t) => pw.Center(
        child: pw.Container(
          padding: pw.EdgeInsets.symmetric(horizontal: 6 * mm, vertical: 1.6 * mm),
          decoration: pw.BoxDecoration(
            color: s.titleBg,
            borderRadius: pw.BorderRadius.circular(4 * mm),
          ),
          child: pw.Text(t,
              style: pw.TextStyle(font: f.bold, fontSize: 9, color: s.titleFg)),
        ),
      );

  pw.Widget _pageNumber(int n) => pw.Align(
        alignment: pw.Alignment.bottomCenter,
        child: pw.Text('$n',
            style: pw.TextStyle(font: f.regular, fontSize: 5.5, color: PdfColors.grey600)),
      );

  pw.Widget _rule({double width = 0.4}) =>
      pw.Container(height: width, color: s.rule);

  /// Rayado simple con paso en mm.
  pw.Widget _ruled(double stepMm, {int? count}) {
    final avail = AgendaSpec.frameH - AgendaSpec.innerPad * 2 - 14; // menos título
    final n = count ?? (avail / stepMm).floor();
    return pw.Column(
      children: List.generate(
          n,
          (i) => pw.Container(
              height: stepMm * mm,
              alignment: pw.Alignment.bottomCenter,
              child: _rule())),
    );
  }

  /// Pauta de caligrafía: línea continua, punteada al medio, línea continua.
  pw.Widget _handwritingRows(int rows) {
    return pw.Column(
      children: List.generate(rows, (i) {
        return pw.Container(
          height: 11 * mm,
          child: pw.Column(children: [
            pw.SizedBox(height: 3.5 * mm),
            _rule(),
            pw.Container(
              height: 3 * mm,
              alignment: pw.Alignment.bottomCenter,
              child: pw.Container(
                height: 0.3,
                decoration: pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(
                            color: s.accent, width: 0.3, style: pw.BorderStyle.dotted))),
              ),
            ),
            pw.SizedBox(height: 3 * mm),
            _rule(),
          ]),
        );
      }),
    );
  }

  pw.Widget _labelLine(String label) => pw.Padding(
        padding: pw.EdgeInsets.only(top: 4 * mm),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 4 * mm),
          _rule(),
        ]),
      );

  pw.Widget _box(double hMm) => pw.Container(
        height: hMm * mm,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: s.frame, width: 0.6),
          borderRadius: pw.BorderRadius.circular(2 * mm),
        ),
      );

  pw.Widget _pageBody(PageDef def, int number) {
    pw.Widget body;
    switch (def.kind) {
      case PageKind.owner:
        body = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 4 * mm),
          for (final l in ['Mi nombre:', 'Mi curso:', 'Mi colegio:', 'Mi profesora:', 'Algo que me gusta:', 'Mi superpoder:'])
            _labelLine(l),
        ]);
        break;
      case PageKind.notes:
        body = pw.Column(children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 2 * mm),
          _ruled(9),
        ]);
        break;
      case PageKind.handwriting:
        body = pw.Column(children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 2 * mm),
          _handwritingRows(13),
        ]);
        break;
      case PageKind.calendar:
        body = _calendar(def.year!, def.halfIndex!);
        break;
      case PageKind.drawWrite:
        body = pw.Column(children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 3 * mm),
          _box(70),
          pw.SizedBox(height: 2 * mm),
          _handwritingRows(7),
        ]);
        break;
      case PageKind.feelings:
        body = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Fecha: ________________', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Hoy me siento: ________________', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Porque:', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          _ruled(9, count: 6),
          pw.SizedBox(height: 4 * mm),
          pw.Text('Dibujo cómo me siento:', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 2 * mm),
          _box(42),
        ]);
        break;
      case PageKind.therapyTasks:
        body = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Fecha: ________________', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 2 * mm),
          for (var i = 0; i < 8; i++)
            pw.Container(
              height: 16 * mm,
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Container(
                  width: 4 * mm, height: 4 * mm,
                  margin: pw.EdgeInsets.only(right: 3 * mm, bottom: 0.5 * mm),
                  decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, border: pw.Border.all(color: s.accent, width: 0.6)),
                ),
                pw.Expanded(child: _rule()),
              ]),
            ),
        ]);
        break;
      case PageKind.homework:
        body = pw.Column(children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 2 * mm),
          _ruled(12),
        ]);
        break;
      case PageKind.savings:
        body = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Mi meta de ahorro: \$ ________________', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 2 * mm),
          pw.Text('Quiero ahorrar para: ________________', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 3 * mm),
          pw.Table(
            border: pw.TableBorder.all(color: s.frame, width: 0.5),
            columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1.4)},
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: s.titleBg),
                children: [for (final h in ['Fecha', 'Ahorré \$', 'Total \$'])
                  pw.Padding(padding: pw.EdgeInsets.all(1.5 * mm), child: pw.Text(h, style: pw.TextStyle(font: f.bold, fontSize: 6, color: s.titleFg)))],
              ),
              for (var i = 0; i < 12; i++)
                pw.TableRow(children: [for (var c = 0; c < 3; c++) pw.SizedBox(height: 8 * mm)]),
            ],
          ),
          pw.SizedBox(height: 4 * mm),
          pw.Text('Total ahorrado: \$ ________________', style: pw.TextStyle(font: f.bold, fontSize: 6.5, color: s.titleFg)),
        ]);
        break;
      case PageKind.achievements:
        body = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 2 * mm),
          for (var i = 1; i <= 10; i++)
            pw.Container(
              height: 15 * mm,
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Container(width: 6 * mm, child: pw.Text('$i.', style: pw.TextStyle(font: f.bold, fontSize: 7, color: s.accent))),
                pw.Expanded(child: _rule()),
              ]),
            ),
        ]);
        break;
      case PageKind.creative:
        body = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Hoy quiero escribir sobre: ________________', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 1 * mm),
          _handwritingRows(12),
        ]);
        break;
      case PageKind.namePage:
        body = pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          if (job.characterArt != null)
            pw.Container(
              height: 70 * mm,
              child: pw.Image(pw.MemoryImage(job.characterArt!), fit: pw.BoxFit.contain),
            ),
          pw.SizedBox(height: 6 * mm),
          pw.Text(job.name, style: pw.TextStyle(font: f.bold, fontSize: 16, color: s.titleFg)),
          pw.SizedBox(height: 2 * mm),
          if (job.phrase.isNotEmpty)
            pw.Text(job.phrase, textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: f.regular, fontSize: 7, color: s.titleFg)),
          pw.SizedBox(height: 6 * mm),
          pw.Text('Mis ideas y mis acuerdos', style: pw.TextStyle(font: f.regular, fontSize: 6, color: PdfColors.grey600)),
        ]);
        break;
      case PageKind.custom:
        body = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title(def.title ?? ''),
          pw.SizedBox(height: 3 * mm),
          _customLayout(def.layout ?? CustomLayout.ruled),
        ]);
        break;
      case PageKind.blank:
        body = pw.SizedBox();
        break;
    }
    return pw.Stack(children: [
      body,
      _pageNumber(number),
    ]);
  }

  pw.Widget _customLayout(CustomLayout l) {
    final availH = AgendaSpec.frameH - AgendaSpec.innerPad * 2 - 18;
    final availW = AgendaSpec.frameW - AgendaSpec.innerPad * 2;
    switch (l) {
      case CustomLayout.ruled:
        return _ruled(9);
      case CustomLayout.handwriting:
        return _handwritingRows(13);
      case CustomLayout.checklist:
        return pw.Column(children: [
          for (var i = 0; i < 12; i++)
            pw.Container(
              height: 12 * mm,
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Container(
                  width: 4 * mm, height: 4 * mm,
                  margin: pw.EdgeInsets.only(right: 3 * mm, bottom: 0.5 * mm),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: s.accent, width: 0.6),
                      borderRadius: pw.BorderRadius.circular(1 * mm)),
                ),
                pw.Expanded(child: _rule()),
              ]),
            ),
        ]);
      case CustomLayout.grid:
        final cols = (availW / 5).floor();
        final rows = (availH / 5).floor();
        return pw.Table(
          border: pw.TableBorder.all(color: s.rule, width: 0.25),
          children: [for (var r = 0; r < rows; r++)
            pw.TableRow(children: [for (var c = 0; c < cols; c++) pw.SizedBox(height: 5 * mm)])],
        );
      case CustomLayout.dotted:
        final cols = (availW / 5).floor();
        final rows = (availH / 5).floor();
        return pw.Column(children: [
          for (var r = 0; r < rows; r++)
            pw.Container(
              height: 5 * mm,
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                for (var c = 0; c < cols; c++)
                  pw.Container(width: 0.8 * mm, height: 0.8 * mm,
                      decoration: pw.BoxDecoration(color: s.rule, shape: pw.BoxShape.circle)),
              ]),
            ),
        ]);
      case CustomLayout.table:
        return pw.Table(
          border: pw.TableBorder.all(color: s.frame, width: 0.5),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: s.titleBg),
              children: [for (var c = 0; c < 3; c++) pw.SizedBox(height: 7 * mm)],
            ),
            for (var i = 0; i < 16; i++)
              pw.TableRow(children: [for (var c = 0; c < 3; c++) pw.SizedBox(height: 9 * mm)]),
          ],
        );
      case CustomLayout.box:
        return pw.Column(children: [_box(80), pw.SizedBox(height: 3 * mm), _ruled(9, count: 7)]);
      case CustomLayout.numbered:
        return pw.Column(children: [
          for (var i = 1; i <= 12; i++)
            pw.Container(
              height: 12.5 * mm,
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Container(width: 6 * mm, child: pw.Text('$i.', style: pw.TextStyle(font: f.bold, fontSize: 7, color: s.accent))),
                pw.Expanded(child: _rule()),
              ]),
            ),
        ]);
    }
  }

  // ---------- Calendario: 6 meses por página ----------

  static const _months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  static const _dow = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  pw.Widget _calendar(int year, int half) {
    final first = half == 0 ? 1 : 7;
    final months = [for (var m = first; m < first + 6; m++) m];
    return pw.Column(children: [
      _title('Calendario $year'),
      pw.SizedBox(height: 1 * mm),
      pw.Text(half == 0 ? 'Enero – Junio' : 'Julio – Diciembre',
          style: pw.TextStyle(font: f.regular, fontSize: 5.5, color: PdfColors.grey600)),
      pw.SizedBox(height: 2 * mm),
      pw.Expanded(
        child: pw.GridView(
          crossAxisCount: 2,
          childAspectRatio: 1.05,
          crossAxisSpacing: 3 * mm,
          mainAxisSpacing: 2 * mm,
          children: [for (final m in months) _month(year, m)],
        ),
      ),
    ]);
  }

  pw.Widget _month(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final offset = (firstDay.weekday + 6) % 7; // lunes = 0
    final cells = <String>[...List.filled(offset, ''),
      for (var d = 1; d <= daysInMonth; d++) '$d'];
    while (cells.length % 7 != 0) {
      cells.add('');
    }
    final rows = <pw.TableRow>[
      pw.TableRow(children: [for (final d in _dow)
        pw.Center(child: pw.Text(d, style: pw.TextStyle(font: f.bold, fontSize: 4.5, color: s.accent)))]),
      for (var r = 0; r < cells.length ~/ 7; r++)
        pw.TableRow(children: [for (var c = 0; c < 7; c++)
          pw.Center(child: pw.Text(cells[r * 7 + c],
              style: pw.TextStyle(font: f.regular, fontSize: 4.5,
                  color: c == 6 ? s.accent : PdfColors.grey800)))]),
    ];
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(_months[month - 1], style: pw.TextStyle(font: f.bold, fontSize: 5.5, color: s.titleFg)),
      pw.SizedBox(height: 0.8 * mm),
      pw.Table(children: rows, defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle),
    ]);
  }

  // ---------- Portada: hoja aparte ----------

  Future<Uint8List> buildCover() async {
    final doc = pw.Document(title: 'Agenda ${job.name} — portada');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(letterW * mm, letterH * mm),
      margin: pw.EdgeInsets.zero,
      build: (ctx) {
        final left = (letterW - AgendaSpec.coverW) / 2;
        final top = (letterH - AgendaSpec.coverH) / 2;
        return pw.Stack(children: [
          pw.Positioned(
            left: left * mm,
            top: top * mm,
            child: pw.Container(
              width: AgendaSpec.coverW * mm,
              height: AgendaSpec.coverH * mm,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.2)),
              child: pw.Stack(fit: pw.StackFit.expand, children: [
                if (job.coverArt != null)
                  pw.Image(pw.MemoryImage(job.coverArt!), fit: pw.BoxFit.cover)
                else
                  pw.Container(color: s.titleBg),
                // nombre y frase sobre una banda blanca translúcida en el tercio inferior
                pw.Positioned(
                  left: 10 * mm,
                  right: 10 * mm,
                  bottom: 22 * mm,
                  child: pw.Container(
                    padding: pw.EdgeInsets.symmetric(vertical: 4 * mm, horizontal: 5 * mm),
                    decoration: pw.BoxDecoration(
                      color: PdfColor(1, 1, 1, 0.85),
                      borderRadius: pw.BorderRadius.circular(5 * mm),
                    ),
                    child: pw.Column(children: [
                      pw.Text(job.name, textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(font: f.bold, fontSize: 22, color: s.titleFg)),
                      if (job.phrase.isNotEmpty) ...[
                        pw.SizedBox(height: 1.5 * mm),
                        pw.Text(job.phrase, textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: f.medium, fontSize: 8.5, color: s.titleFg)),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          // marcas de corte
          ..._cropMarks(left, top, AgendaSpec.coverW, AgendaSpec.coverH),
        ]);
      },
    ));
    return doc.save();
  }

  static List<pw.Widget> _cropMarks(double x, double y, double w, double h) {
    const len = 4.0, gap = 1.0;
    pw.Widget hline(double px, double py) => pw.Positioned(
        left: px * mm, top: py * mm, child: pw.Container(width: len * mm, height: 0.25, color: PdfColors.grey700));
    pw.Widget vline(double px, double py) => pw.Positioned(
        left: px * mm, top: py * mm, child: pw.Container(width: 0.25, height: len * mm, color: PdfColors.grey700));
    return [
      hline(x - len - gap, y), hline(x + w + gap, y),
      hline(x - len - gap, y + h), hline(x + w + gap, y + h),
      vline(x, y - len - gap), vline(x + w, y - len - gap),
      vline(x, y + h + gap), vline(x + w, y + h + gap),
    ];
  }
}
