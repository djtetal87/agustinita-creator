import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Mini agenda: 8 páginas (107,95 × 139,7 mm) impuestas en una hoja carta
/// doble cara (volteo por borde largo), cortada a la mitad horizontal.
class MiniBookletJob {
  /// 8 imágenes en orden de lectura: Tapa, Contratapa, Actividad 1..6.
  /// En la vista previa puede haber nulos (se dibuja un recuadro vacío).
  final List<Uint8List?> images;
  final List<bool> rotate90;
  final bool fill; // true = Rellenar (cover), false = Completa (contain)
  final double marginMm;
  final bool guides;
  final double backOffsetX;
  final double backOffsetY;
  final int copies;
  const MiniBookletJob({
    required this.images,
    required this.rotate90,
    this.fill = false,
    this.marginMm = 0,
    this.guides = true,
    this.backOffsetX = 0,
    this.backOffsetY = 0,
    this.copies = 1,
  });
}

class MiniBookletBuilder {
  static const double mm = PdfPageFormat.mm;
  static const double sheetW = 215.9 * mm;
  static const double sheetH = 279.4 * mm;
  static const double qW = 107.95 * mm;
  static const double qH = 139.7 * mm;
  static final PdfPageFormat format = PdfPageFormat(sheetW, sheetH, marginAll: 0);

  static const labels = ['Tapa', 'Contratapa', 'Actividad 1', 'Actividad 2', 'Actividad 3', 'Actividad 4', 'Actividad 5', 'Actividad 6'];

  /// Índices (en la lista de 8 imágenes) por cuadrante [TL, TR, BL, BR].
  /// Imagen: 0 Tapa(p1), 1 Contratapa(p8), 2..7 Act1..6 (p2..p7).
  static const frontOrder = [1, 0, 6, 3]; // p8, p1, p6(Act5), p3(Act2)
  static const backOrder = [2, 7, 4, 5]; // p2(Act1), p7(Act6), p4(Act3), p5(Act4)

  static const _quadX = [0.0, qW, 0.0, qW];
  static const _quadY = [0.0, 0.0, qH, qH];

  static Future<Uint8List> build(MiniBookletJob job) async {
    final doc = pw.Document(title: 'Mini agenda navideña', author: 'Agustinita Creator');
    final provs = <pw.MemoryImage?>[
      for (final b in job.images) b == null ? null : pw.MemoryImage(b),
    ];
    for (var c = 0; c < job.copies; c++) {
      doc.addPage(_page(() => _content(job, provs, frontOrder, 0, 0, 'FRENTE', job.guides)));
      doc.addPage(_page(() => _content(job, provs, backOrder, job.backOffsetX, job.backOffsetY, 'REVERSO', false)));
    }
    return doc.save();
  }

  static pw.Page _page(pw.Widget Function() child) => pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => child(),
      );

  static pw.Widget _content(MiniBookletJob job, List<pw.MemoryImage?> provs, List<int> order, double offX, double offY,
      String side, bool guides) {
    final dx = offX * mm, dy = offY * mm;
    final children = <pw.Widget>[];
    for (var q = 0; q < 4; q++) {
      final idx = order[q];
      children.add(pw.Positioned(
        left: _quadX[q] + dx,
        top: _quadY[q] + dy,
        child: pw.SizedBox(
          width: qW,
          height: qH,
          child: _quadrant(job, provs[idx], job.rotate90[idx], idx),
        ),
      ));
    }
    if (guides) children.add(_paint((c) => _drawGuides(c)));
    return pw.SizedBox(width: sheetW, height: sheetH, child: pw.Stack(children: children));
  }

  static pw.Widget _paint(void Function(PdfGraphics c) draw) => pw.Positioned(
        left: 0,
        top: 0,
        child: pw.SizedBox(
          width: sheetW,
          height: sheetH,
          child: pw.CustomPaint(size: const PdfPoint(sheetW, sheetH), painter: (canvas, size) => draw(canvas)),
        ),
      );

  /// Contenido de un cuadrante de exactamente qW × qH.
  static pw.Widget _quadrant(MiniBookletJob job, pw.MemoryImage? img, bool rot, int idx) {
    if (img == null) {
      return pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        alignment: pw.Alignment.center,
        child: pw.Text(labels[idx], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      );
    }
    if (job.fill) {
      return _place(img, qW, qH, rot, cover: true);
    }
    final m = job.marginMm * mm;
    final bw = qW - 2 * m, bh = qH - 2 * m;
    return pw.Stack(children: [
      pw.Positioned(left: m, top: m, child: _place(img, bw, bh, rot, cover: false)),
    ]);
  }

  /// Devuelve un SizedBox(bw × bh) con la imagen centrada exactamente.
  static pw.Widget _place(pw.MemoryImage img, double bw, double bh, bool rot, {required bool cover}) {
    if (rot) {
      // Se compone en un marco con ejes intercambiados y se gira 90°.
      return pw.SizedBox(
        width: bw,
        height: bh,
        child: pw.Transform.rotateBox(angle: -math.pi / 2, child: _fit(img, bh, bw, cover)),
      );
    }
    return _fit(img, bw, bh, cover);
  }

  static pw.Widget _fit(pw.MemoryImage img, double bw, double bh, bool cover) {
    final iw = (img.width ?? 1).toDouble();
    final ih = (img.height ?? 1).toDouble();
    final s = cover ? math.max(bw / iw, bh / ih) : math.min(bw / iw, bh / ih);
    final w = iw * s, h = ih * s;
    final left = (bw - w) / 2, top = (bh - h) / 2;
    final stack = pw.SizedBox(
      width: bw,
      height: bh,
      child: pw.Stack(overflow: pw.Overflow.visible, children: [
        pw.Positioned(left: left, top: top, child: pw.Image(img, width: w, height: h, fit: pw.BoxFit.fill)),
      ]),
    );
    return cover ? pw.ClipRect(child: stack) : stack;
  }

  // ---- guías ----
  static void _drawGuides(PdfGraphics c) {
    c
      ..setStrokeColor(PdfColors.grey600)
      ..setLineWidth(0.3);
    const t = 5 * mm;
    const midY = sheetH / 2; // coordenadas PDF: origen abajo
    const midX = sheetW / 2;
    // marcas de corte (horizontal) en bordes izquierdo y derecho
    c.drawLine(0, midY, t, midY);
    c.drawLine(sheetW - t, midY, sheetW, midY);
    // marcas de doblez: bordes superior e inferior en x central
    c.drawLine(midX, sheetH, midX, sheetH - t);
    c.drawLine(midX, 0, midX, t);
    // y sobre la línea central (cruce de corte y doblez), tick corto
    c.drawLine(midX, midY - 2.5 * mm, midX, midY + 2.5 * mm);
    c.strokePath();
  }

  // ---- hoja de prueba ----
  static Future<Uint8List> buildAlignmentTest({double backOffsetX = 0, double backOffsetY = 0}) async {
    final doc = pw.Document(title: 'Prueba de alineación');
    doc.addPage(_page(() => _testPage(0, 0, false)));
    doc.addPage(_page(() => _testPage(backOffsetX, backOffsetY, true)));
    return doc.save();
  }

  static pw.Widget _testPage(double offX, double offY, bool back) {
    final dx = offX * mm, dy = offY * mm; // dy positivo = hacia abajo
    final kids = <pw.Widget>[
      _paint((c) => _drawTest(c, dx, -dy)),
    ];
    kids.add(pw.Positioned(
      left: 10 * mm + dx,
      top: 6 * mm + dy,
      child: pw.SizedBox(
        width: sheetW - 20 * mm,
        child: pw.Text(
          back
              ? 'REVERSO. Mira a contraluz: si las cruces no coinciden, mide la diferencia en mm y ajústala en "Ajuste del reverso".'
              : 'FRENTE. Esta cara es la referencia.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
        ),
      ),
    ));
    return pw.SizedBox(width: sheetW, height: sheetH, child: pw.Stack(children: kids));
  }

  static void _cross(PdfGraphics c, double x, double y, double r, double lw) {
    c
      ..setLineWidth(lw)
      ..drawLine(x - r, y, x + r, y)
      ..drawLine(x, y - r, x, y + r)
      ..strokePath();
  }

  static void _drawTest(PdfGraphics c, double dx, double dy) {
    c.setStrokeColor(PdfColors.black);
    final cx = sheetW / 2 + dx, cy = sheetH / 2 + dy;
    // cruz central de la hoja (grande, fina)
    _cross(c, cx, cy, 15 * mm, 0.25);
    // cruces al centro de cada cuadrante
    for (var q = 0; q < 4; q++) {
      final x = _quadX[q] + qW / 2 + dx;
      final y = sheetH - (_quadY[q] + qH / 2) + dy;
      _cross(c, x, y, 8 * mm, 0.25);
    }
    // regla con marcas cada 1 mm a lo largo de las líneas centrales
    c.setStrokeColor(PdfColors.grey700);
    c.setLineWidth(0.15);
    for (var i = -30; i <= 30; i++) {
      final len = (i % 10 == 0) ? 3.0 : (i % 5 == 0 ? 2.0 : 1.0);
      final l = len * mm / 2;
      // sobre la línea horizontal central
      c.drawLine(cx + i * mm, cy - l, cx + i * mm, cy + l);
      // sobre la línea vertical central
      c.drawLine(cx - l, cy + i * mm, cx + l, cy + i * mm);
    }
    c.strokePath();
  }
}
