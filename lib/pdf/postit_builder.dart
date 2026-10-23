import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../specs.dart';
import '../theme_spec.dart';
import 'fonts.dart';

/// Qué va dentro del post-it (lo dibuja la app, no la IA).
enum PostitContent { ruled, checklist, weekdays, grid, dotted, blank }

const postitContentLabels = <PostitContent, String>{
  PostitContent.ruled: 'Rayado',
  PostitContent.checklist: 'Checklist',
  PostitContent.weekdays: 'Días de la semana',
  PostitContent.grid: 'Cuadrícula',
  PostitContent.dotted: 'Punteado',
  PostitContent.blank: 'Liso',
};

class PostitJob {
  final PostitSpec spec;
  final StyleSpec style;
  final String title; // "Compras", "Plan de comidas", "" = sin título
  final PostitContent content;
  final Uint8List frameArt; // marco generado por la IA (centro claro)
  final int sheets; // cuántas hojas carta repetir

  const PostitJob({
    required this.spec,
    required this.style,
    required this.title,
    required this.content,
    required this.frameArt,
    this.sheets = 1,
  });
}

class PostitBuilder {
  final PostitJob job;
  final PdfFonts f;
  PostitBuilder(this.job, this.f);

  StyleSpec get s => job.style;
  PostitSpec get p => job.spec;

  /// Posiciones (x, y en mm) de cada bloque en la hoja carta vertical,
  /// copiadas de los archivos de producción.
  List<List<double>> get _positions {
    switch (p.id) {
      case 'cuadrado':
        return [
          [6.2, 37.9], [109.7, 37.9],
          [6.2, 141.4], [109.7, 141.4],
        ];
      case 'horizontal':
        return [
          [32.9, 45.7], [32.9, 143.7],
        ];
      default: // vertical: 3 en fila
        return [
          [3.0, 4.5], [72.9, 4.5], [143.0, 4.5],
        ];
    }
  }

  Future<Uint8List> build() async {
    final doc = pw.Document(title: 'Post-it ${p.label} — ${job.title}');
    final art = pw.MemoryImage(job.frameArt);
    for (var n = 0; n < job.sheets; n++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(letterW * mm, letterH * mm),
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(children: [
          for (final pos in _positions) ...[
            pw.Positioned(
              left: pos[0] * mm,
              top: pos[1] * mm,
              child: _block(art),
            ),
            ..._cropMarks(pos[0], pos[1], p.w, p.h),
          ],
        ]),
      ));
    }
    return doc.save();
  }

  pw.Widget _block(pw.MemoryImage art) {
    // Zona útil dentro del marco ilustrado (porcentajes del bloque).
    final hasTitle = job.title.trim().isNotEmpty;
    final insetX = p.w * 0.13;
    final insetTop = p.h * (hasTitle ? 0.24 : 0.14);
    final insetBottom = p.h * 0.20;
    return pw.SizedBox(
      width: p.w * mm,
      height: p.h * mm,
      child: pw.Stack(fit: pw.StackFit.expand, children: [
        pw.Image(art, fit: pw.BoxFit.cover),
        if (hasTitle)
          pw.Positioned(
            left: insetX * mm,
            right: insetX * mm,
            top: p.h * 0.07 * mm,
            child: pw.Center(
              child: pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 4 * mm, vertical: 1.2 * mm),
                decoration: pw.BoxDecoration(
                  color: PdfColor(1, 1, 1, 0.8),
                  borderRadius: pw.BorderRadius.circular(4 * mm),
                ),
                child: pw.Text(job.title,
                    style: pw.TextStyle(font: f.title, fontSize: (p.w < 80 ? 9 : 12) * f.scriptScale, color: s.titleFg)),
              ),
            ),
          ),
        pw.Positioned(
          left: insetX * mm,
          right: insetX * mm,
          top: insetTop * mm,
          bottom: insetBottom * mm,
          child: _content(p.w - insetX * 2, p.h - insetTop - insetBottom),
        ),
      ]),
    );
  }

  pw.Widget _rule() => pw.Container(height: 0.4, color: s.rule);

  pw.Widget _content(double wMm, double hMm) {
    switch (job.content) {
      case PostitContent.ruled:
        final n = (hMm / 7.5).floor();
        return pw.Column(children: [
          for (var i = 0; i < n; i++)
            pw.Container(height: 7.5 * mm, alignment: pw.Alignment.bottomCenter, child: _rule()),
        ]);
      case PostitContent.checklist:
        final n = (hMm / 8).floor();
        return pw.Column(children: [
          for (var i = 0; i < n; i++)
            pw.Container(
              height: 8 * mm,
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Container(
                  width: 3.6 * mm, height: 3.6 * mm,
                  margin: pw.EdgeInsets.only(right: 2.5 * mm, bottom: 0.4 * mm),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: s.accent, width: 0.6),
                    borderRadius: pw.BorderRadius.circular(0.8 * mm),
                  ),
                ),
                pw.Expanded(child: _rule()),
              ]),
            ),
        ]);
      case PostitContent.weekdays:
        const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final rowH = hMm / 7;
        return pw.Column(children: [
          for (final d in days)
            pw.Container(
              height: rowH * mm,
              padding: pw.EdgeInsets.symmetric(vertical: 0.8 * mm),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColor(1, 1, 1, 0.75),
                  border: pw.Border.all(color: s.frame, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(2.5 * mm),
                ),
                padding: pw.EdgeInsets.symmetric(horizontal: 2.5 * mm),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(d, style: pw.TextStyle(font: f.bold, fontSize: 6, color: s.titleFg)),
              ),
            ),
        ]);
      case PostitContent.grid:
        final cols = (wMm / 5).floor();
        final rows = (hMm / 5).floor();
        return pw.Table(
          border: pw.TableBorder.all(color: s.rule, width: 0.25),
          children: [for (var r = 0; r < rows; r++)
            pw.TableRow(children: [for (var c = 0; c < cols; c++) pw.SizedBox(height: 5 * mm)])],
        );
      case PostitContent.dotted:
        final cols = (wMm / 5).floor();
        final rows = (hMm / 5).floor();
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
      case PostitContent.blank:
        return pw.SizedBox();
    }
  }

  static List<pw.Widget> _cropMarks(double x, double y, double w, double h) {
    const len = 3.5, gap = 0.8;
    pw.Widget hline(double px, double py) => pw.Positioned(
        left: px * mm, top: py * mm, child: pw.Container(width: len * mm, height: 0.25, color: PdfColors.grey800));
    pw.Widget vline(double px, double py) => pw.Positioned(
        left: px * mm, top: py * mm, child: pw.Container(width: 0.25, height: len * mm, color: PdfColors.grey800));
    final out = <pw.Widget>[];
    if (x - len - gap >= 0) { out.add(hline(x - len - gap, y)); out.add(hline(x - len - gap, y + h)); }
    if (x + w + gap + len <= letterW) { out.add(hline(x + w + gap, y)); out.add(hline(x + w + gap, y + h)); }
    if (y - len - gap >= 0) { out.add(vline(x, y - len - gap)); out.add(vline(x + w, y - len - gap)); }
    if (y + h + gap + len <= letterH) { out.add(vline(x, y + h + gap)); out.add(vline(x + w, y + h + gap)); }
    return out;
  }
}
