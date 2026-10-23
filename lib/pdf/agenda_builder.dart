import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../planner/holidays_cl.dart';
import '../planner/sections.dart';
import '../specs.dart';
import '../theme_spec.dart';
import 'fonts.dart';

part 'planner_pages.dart';

/// Datos que vienen del formulario de Agenda.
class AgendaJob {
  final String name;
  final String phrase;
  final StyleSpec style;
  final List<PageDef> pages; // agenda infantil clásica (si plannerPages == null)
  final List<PlannerPage>? plannerPages; // planner por secciones
  final Uint8List? separatorArt; // arte de los separadores de mes (página completa)
  final Uint8List? coverArt; // ilustración generada (portada)
  final Uint8List? characterArt; // personaje (foto → personaje) para la página del nombre
  final Uint8List? interiorArt; // marco ilustrado para todas las páginas interiores
  final bool coverHasText; // true = no escribir nombre/frase sobre la portada
  final bool mirrorBack; // margen de anillos a la derecha en el reverso
  final AgendaSpec spec; // A5 o media carta
  final Map<int, Uint8List> separatorArts; // arte por mes (1-12); si falta, separatorArt
  final CharacterOverlay overlay; // personaje semitransparente en las páginas con pauta
  /// true: una página por hoja del PDF (A5 / media carta), para imprimir a
  /// doble cara directo. false: 2 páginas por hoja (A4 / carta) para cortar.
  final bool singlePages;
  /// true: la ilustración cubre toda la página (sin marco redondeado); el
  /// contenido queda en un área segura que respeta el anillado.
  final bool fullBleedArt;
  /// Sangrado en mm (0 = sin sangrado). Solo aplica con singlePages.
  final double bleedMm;

  const AgendaJob({
    required this.name,
    required this.phrase,
    required this.style,
    this.pages = const [],
    this.plannerPages,
    this.separatorArt,
    this.coverArt,
    this.characterArt,
    this.interiorArt,
    this.coverHasText = false,
    this.mirrorBack = false,
    this.spec = AgendaSpec.a5,
    this.separatorArts = const {},
    this.overlay = const CharacterOverlay(),
    this.singlePages = false,
    this.fullBleedArt = true,
    this.bleedMm = 0,
  });
}

/// Dónde y cómo va el personaje sobre las páginas interiores.
class CharacterOverlay {
  final bool enabled;
  final String corner; // br, bl, tr, tl
  final double sizePct; // fracción de la altura de la página (0.10–0.30)
  final double opacity; // 0–1
  const CharacterOverlay({this.enabled = true, this.corner = 'br', this.sizePct = 0.18, this.opacity = 0.30});
}

class AgendaBuilder {
  final AgendaJob job;
  final PdfFonts f;
  AgendaBuilder(this.job, this.f);

  StyleSpec get s => job.style;
  AgendaSpec get sp => job.spec;
  late final pw.MemoryImage? _interior =
      job.interiorArt == null ? null : pw.MemoryImage(job.interiorArt!);
  late final pw.MemoryImage? _character =
      job.characterArt == null ? null : pw.MemoryImage(job.characterArt!);
  final Map<int, pw.MemoryImage> _sepCache = {};
  pw.MemoryImage? _separatorFor(int month) {
    final b = job.separatorArts[month];
    if (b == null) return _separator;
    return _sepCache.putIfAbsent(month, () => pw.MemoryImage(b));
  }

  late final pw.MemoryImage? _separator = job.separatorArt != null
      ? pw.MemoryImage(job.separatorArt!)
      : job.coverArt != null
          ? pw.MemoryImage(job.coverArt!)
          : null;

  // ---------- Interior: hojas carta horizontales, 2 páginas por cara ----------

  /// Una página lista para colocar en media hoja.
  pw.Widget _pageWidget(int i, int number, bool ringLeft, {double bleed = 0}) {
    final pp = job.plannerPages;
    if (pp != null) {
      if (i >= pp.length) return _half(null, number, ringLeft, bleed: bleed);
      final p = pp[i];
      final art = sectionDef(p.kind).artOnly;
      return _half(_bodyWithNumber(plannerBody(p), number), number, ringLeft, artPage: art, month: p.month, bleed: bleed);
    }
    if (i >= job.pages.length) return _half(null, number, ringLeft, bleed: bleed);
    final def = job.pages[i];
    if (def.kind == PageKind.blank) return _half(null, number, ringLeft, bleed: bleed);
    return _half(_pageBody(def, number), number, ringLeft, artPage: def.kind == PageKind.namePage, bleed: bleed);
  }

  int get _pageCount => job.plannerPages?.length ?? job.pages.length;

  Future<Uint8List> buildInterior() async {
    if (job.singlePages) return _buildSinglePages();
    final doc = pw.Document(title: 'Agenda ${job.name} — interior');
    var n = _pageCount;
    while (n % 4 != 0) {
      n++;
    }
    for (var i = 0; i < n; i += 4) {
      doc.addPage(_sheet(i, i + 1, ringLeft: true)); // cara frontal
      doc.addPage(_sheet(i + 2, i + 3, ringLeft: !job.mirrorBack)); // reverso
    }
    return doc.save();
  }

  /// Una página por hoja del PDF. Páginas impares (frente): anillos a la
  /// izquierda; pares (reverso): anillos a la derecha, para que al imprimir a
  /// doble cara el anillado quede siempre del mismo lado físico.
  Future<Uint8List> _buildSinglePages() async {
    final doc = pw.Document(title: 'Agenda ${job.name} — páginas sueltas');
    var n = _pageCount;
    if (n.isOdd) n++;
    final b = job.bleedMm;
    for (var i = 0; i < n; i++) {
      final front = i.isEven; // página 1, 3, 5… = frente
      final ringLeft = front ? true : job.mirrorBack;
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat((sp.halfW + 2 * b) * mm, (sp.sheetH + 2 * b) * mm),
        margin: pw.EdgeInsets.zero,
        build: (ctx) => b == 0
            ? _pageWidget(i, i + 1, ringLeft)
            : pw.Stack(children: [
                // la ilustración se extiende al sangrado; el contenido queda centrado
                pw.Positioned(left: b * mm, top: b * mm, child: _pageWidget(i, i + 1, ringLeft, bleed: b)),
                ..._cropMarks(b, b, sp.halfW, sp.sheetH),
              ]),
      ));
    }
    return doc.save();
  }

  pw.Page _sheet(int ia, int ib, {required bool ringLeft}) {
    return pw.Page(
      pageFormat: PdfPageFormat(sp.sheetW * mm, sp.sheetH * mm),
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Stack(children: [
        pw.Positioned(left: 0, top: 0, child: _pageWidget(ia, ia + 1, ringLeft)),
        pw.Positioned(
            left: sp.halfW * mm, top: 0, child: _pageWidget(ib, ib + 1, ringLeft)),
        // marca de corte central
        pw.Positioned(
          left: sp.halfW * mm - 0.15,
          top: 0,
          child: pw.Container(width: 0.3, height: 4 * mm, color: PdfColors.grey600),
        ),
        pw.Positioned(
          left: sp.halfW * mm - 0.15,
          top: (sp.sheetH - 4) * mm,
          child: pw.Container(width: 0.3, height: 4 * mm, color: PdfColors.grey600),
        ),
      ]),
    );
  }

  /// Media hoja: una página con su margen para los anillos.
  /// [body] null = página en blanco. [artPage] = fondo de arte completo
  /// (separadores, página del nombre) en vez del marco interior.
  pw.Widget _half(pw.Widget? body, int number, bool ringLeft, {bool artPage = false, int month = 0, double bleed = 0}) {
    final isBlank = body == null;
    final bg = artPage ? (month > 0 ? _separatorFor(month) : _separator) : _interior;
    final ov = job.overlay;
    final showChar = !artPage && ov.enabled && _character != null;

    if (job.fullBleedArt) {
      // ---- Ilustración a página completa + área segura ----
      final W = sp.halfW, H = sp.sheetH;
      // área segura: 20 mm lado anillado, 10 mm lado exterior, 14 mm arriba/abajo
      final ringSide = AgendaSpec.ringMargin + 5.0, outer = 10.0, top = 14.0, bottom = 14.0;
      final left = ringLeft ? ringSide : outer;
      final right = ringLeft ? outer : ringSide;
      final charH = (H - top - bottom) * ov.sizePct;
      return pw.SizedBox(
        width: W * mm,
        height: H * mm,
        child: pw.Stack(children: [
          // fondo: la imagen se extiende [bleed] mm hacia afuera por cada lado
          if (bg != null && !isBlank)
            pw.Positioned(
              left: -bleed * mm, top: -bleed * mm,
              child: pw.Transform(
                // reverso: espejar para que los adornos no caigan en el anillado
                transform: ringLeft
                    ? Matrix4.identity()
                    : (Matrix4.identity()..translate((W + 2 * bleed) * mm, 0.0)..scale(-1.0, 1.0)),
                child: pw.SizedBox(
                  width: (W + 2 * bleed) * mm, height: (H + 2 * bleed) * mm,
                  child: pw.Image(bg, fit: pw.BoxFit.cover),
                ),
              ),
            ),
          if (showChar)
            pw.Positioned(
              left: ov.corner.endsWith('l') ? (left - 4) * mm : null,
              right: ov.corner.endsWith('r') ? (right - 4) * mm : null,
              top: ov.corner.startsWith('t') ? (top - 4) * mm : null,
              bottom: ov.corner.startsWith('b') ? (bottom - 4) * mm : null,
              child: pw.Opacity(
                opacity: ov.opacity,
                child: pw.Container(height: charH * mm, child: pw.Image(_character!, fit: pw.BoxFit.contain)),
              ),
            ),
          if (!isBlank)
            pw.Positioned(
              left: left * mm, top: top * mm,
              child: pw.SizedBox(
                width: (W - left - right) * mm,
                height: (H - top - bottom) * mm,
                child: body,
              ),
            ),
        ]),
      );
    }

    // ---- Modo clásico: marco redondeado ----
    final frameLeft = ringLeft
        ? AgendaSpec.ringMargin
        : sp.halfW - AgendaSpec.ringMargin - sp.frameW;
    final charH = sp.frameH * ov.sizePct;
    return pw.SizedBox(
      width: sp.halfW * mm,
      height: sp.sheetH * mm,
      child: pw.Stack(children: [
        // guía punteada del anillado (no se imprime fuerte)
        pw.Positioned(
          left: (ringLeft ? AgendaSpec.ringMargin : sp.halfW - AgendaSpec.ringMargin) * mm,
          top: 0,
          child: pw.Container(
            width: 0.3,
            height: sp.sheetH * mm,
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
              width: sp.frameW * mm,
              height: sp.frameH * mm,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: s.frame, width: 0.8),
                borderRadius: pw.BorderRadius.circular(AgendaSpec.frameRadius * mm),
              ),
              child: pw.Stack(fit: pw.StackFit.expand, children: [
                if (bg != null)
                  pw.ClipRRect(
                    horizontalRadius: AgendaSpec.frameRadius * mm,
                    verticalRadius: AgendaSpec.frameRadius * mm,
                    child: pw.Image(bg, fit: pw.BoxFit.cover),
                  ),
                if (showChar)
                  pw.Positioned(
                    left: ov.corner.endsWith('l') ? 2 * mm : null,
                    right: ov.corner.endsWith('r') ? 2 * mm : null,
                    top: ov.corner.startsWith('t') ? 2 * mm : null,
                    bottom: ov.corner.startsWith('b') ? 2 * mm : null,
                    child: pw.Opacity(
                      opacity: ov.opacity,
                      child: pw.Container(height: charH * mm, child: pw.Image(_character!, fit: pw.BoxFit.contain)),
                    ),
                  ),
                pw.Padding(
                  padding: artPage || bg == null
                      ? pw.EdgeInsets.all(AgendaSpec.innerPad * mm)
                      : pw.EdgeInsets.fromLTRB(12 * mm, 11 * mm, 12 * mm, 12 * mm),
                  child: body!,
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  // ---------- Contenido de cada tipo de página ----------

  /// Título de página: "Primera" en Poppins Bold + "resto" en cursiva.
  /// Con "|" se fuerza el corte ("Horario | de clases"). Sin píldora de fondo.
  pw.Widget _title(String t, {double size = 11}) {
    final color = s.titleFg;
    final plain = pw.TextStyle(font: f.bold, fontSize: size, color: color);
    final script = pw.TextStyle(font: f.title, fontSize: size * f.scriptScale, color: color);
    pw.Widget w;
    switch (f.titleStyle) {
      case TitleStyle.plain:
        w = pw.Text(t.replaceAll('|', ' ').replaceAll('  ', ' '), style: plain);
        break;
      case TitleStyle.script:
        w = pw.Text(t.replaceAll('|', ' ').replaceAll('  ', ' '), style: script);
        break;
      case TitleStyle.dual:
        String a, b;
        if (t.contains('|')) {
          final i = t.indexOf('|');
          a = t.substring(0, i).trim();
          b = t.substring(i + 1).trim();
        } else {
          final parts = t.trim().split(RegExp(r'\s+'));
          if (parts.length == 1) {
            a = '';
            b = parts.first;
          } else {
            a = parts.first;
            b = parts.sublist(1).join(' ');
          }
        }
        // RichText comparte la línea base entre las dos fuentes
        w = pw.RichText(
          text: pw.TextSpan(children: [
            if (a.isNotEmpty) pw.TextSpan(text: '$a ', style: plain),
            pw.TextSpan(text: b, style: script),
          ]),
        );
        break;
    }
    return pw.Center(child: pw.Padding(padding: pw.EdgeInsets.only(bottom: 1 * mm), child: w));
  }

  pw.Widget _pageNumber(int n) => pw.Align(
        alignment: pw.Alignment.bottomCenter,
        child: pw.Text('$n',
            style: pw.TextStyle(font: f.regular, fontSize: 5.5, color: PdfColors.grey600)),
      );

  pw.Widget _rule({double width = 0.4}) =>
      pw.Container(height: width, color: s.rule);

  /// Rayado simple con paso en mm. Sin [count], llena el espacio disponible.
  pw.Widget _ruled(double stepMm, {int? count}) {
    pw.Widget rows(int n) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: List.generate(
              n,
              (i) => pw.Container(
                  height: stepMm * mm,
                  alignment: pw.Alignment.bottomCenter,
                  child: _rule())),
        );
    if (count != null) return rows(count);
    return pw.Expanded(
      child: pw.LayoutBuilder(
        builder: (ctx, c) => rows(((c?.maxHeight ?? 0) / (stepMm * mm)).floor().clamp(0, 40)),
      ),
    );
  }

  /// Pauta de caligrafía que llena el espacio disponible.
  pw.Widget _handwritingFill() => pw.Expanded(
        child: pw.LayoutBuilder(
          builder: (ctx, c) => _handwritingRows(((c?.maxHeight ?? 0) / (11 * mm)).floor().clamp(0, 30)),
        ),
      );

  /// Pauta de caligrafía: línea continua, punteada al medio, línea continua.
  pw.Widget _handwritingRows(int rows) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
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

  pw.Widget _bodyWithNumber(pw.Widget body, int number) =>
      pw.Stack(fit: pw.StackFit.expand, children: [body, _pageNumber(number)]);

  pw.Widget _pageBody(PageDef def, int number, {bool bare = false}) {
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
          _handwritingFill(),
        ]);
        break;
      case PageKind.calendar:
        body = _calendar(def.year!, def.halfIndex!);
        break;
      case PageKind.drawWrite:
        body = pw.Column(children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 3 * mm),
          _box(60),
          pw.SizedBox(height: 2 * mm),
          _handwritingFill(),
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
          _ruled(9, count: 5),
          pw.SizedBox(height: 4 * mm),
          pw.Text('Dibujo cómo me siento:', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 2 * mm),
          _box(38),
        ]);
        break;
      case PageKind.therapyTasks:
        body = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title(pageTitles[def.kind]!),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Fecha: ________________', style: pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg)),
          pw.SizedBox(height: 2 * mm),
          for (var i = 0; i < 7; i++)
            pw.Container(
              height: 15 * mm,
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
              for (var i = 0; i < 10; i++)
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
          for (var i = 1; i <= 9; i++)
            pw.Container(
              height: 14 * mm,
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
          _handwritingFill(),
        ]);
        break;
      case PageKind.namePage:
        body = pw.Column(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          if (job.characterArt != null && _separator == null)
            pw.Expanded(
              child: pw.Center(child: pw.Container(
                height: 70 * mm,
                child: pw.Image(pw.MemoryImage(job.characterArt!), fit: pw.BoxFit.contain),
              )),
            ),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 4 * mm, horizontal: 6 * mm),
            decoration: pw.BoxDecoration(color: PdfColor(1, 1, 1, 0.85), borderRadius: pw.BorderRadius.circular(5 * mm)),
            child: pw.Column(children: [
              if (job.name.isNotEmpty)
                pw.Text(job.name, style: pw.TextStyle(font: f.display, fontSize: 20, color: s.titleFg)),
              if (job.phrase.isNotEmpty) ...[
                pw.SizedBox(height: 2 * mm),
                pw.Text(job.phrase, textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: f.title, fontSize: 7.5 * f.scriptScale, color: s.titleFg)),
              ],
              pw.SizedBox(height: 3 * mm),
              pw.Text('Agustinita Papelería', style: pw.TextStyle(font: f.regular, fontSize: 5.5, color: PdfColors.grey600)),
            ]),
          ),
          pw.SizedBox(height: 8 * mm),
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
    if (bare) return body;
    // fit expand: la Column con Expanded necesita altura acotada
    return _bodyWithNumber(body, number);
  }

  pw.Widget _customLayout(CustomLayout l) {
    final availH = sp.frameH - AgendaSpec.innerPad * 2 - 18;
    final availW = sp.frameW - AgendaSpec.innerPad * 2;
    switch (l) {
      case CustomLayout.ruled:
        return _ruled(9);
      case CustomLayout.handwriting:
        return _handwritingFill();
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
        return pw.Column(children: [_box(70), pw.SizedBox(height: 3 * mm), _ruled(9)]);
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
    // Página suelta: la portada sale a tamaño de página (+ sangrado); si no,
    // centrada en la hoja grande con marcas de corte.
    final b = job.singlePages ? job.bleedMm : 0.0;
    final pageW = job.singlePages ? sp.coverW + 2 * b : sp.coverSheetW;
    final pageH = job.singlePages ? sp.coverH + 2 * b : sp.coverSheetH;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(pageW * mm, pageH * mm),
      margin: pw.EdgeInsets.zero,
      build: (ctx) {
        final left = (pageW - sp.coverW) / 2;
        final top = (pageH - sp.coverH) / 2;
        return pw.Stack(children: [
          pw.Positioned(
            left: left * mm,
            top: top * mm,
            child: pw.Container(
              width: sp.coverW * mm,
              height: sp.coverH * mm,
              decoration: left > 0 ? pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.2)) : null,
              child: pw.Stack(fit: pw.StackFit.expand, children: [
                if (job.coverArt != null)
                  pw.Positioned(
                    left: -b * mm, top: -b * mm,
                    child: pw.SizedBox(
                      width: (sp.coverW + 2 * b) * mm, height: (sp.coverH + 2 * b) * mm,
                      child: pw.Image(pw.MemoryImage(job.coverArt!), fit: pw.BoxFit.cover),
                    ),
                  )
                else
                  pw.Container(color: s.titleBg),
                // nombre y frase en una banda al borde inferior (no si la portada ya trae texto)
                if (!job.coverHasText)
                pw.Positioned(
                  left: 8 * mm,
                  right: 8 * mm,
                  bottom: 10 * mm,
                  child: pw.Container(
                    padding: pw.EdgeInsets.symmetric(vertical: 4 * mm, horizontal: 5 * mm),
                    decoration: pw.BoxDecoration(
                      color: PdfColor(1, 1, 1, 0.85),
                      borderRadius: pw.BorderRadius.circular(5 * mm),
                    ),
                    child: pw.Column(children: [
                      pw.Text(job.name, textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(font: f.display, fontSize: 26, color: s.titleFg)),
                      if (job.phrase.isNotEmpty) ...[
                        pw.SizedBox(height: 1.5 * mm),
                        pw.Text(job.phrase, textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: f.title, fontSize: 9 * f.scriptScale, color: s.titleFg)),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          // marcas de corte (solo si hay margen alrededor)
          if (left > 0) ..._cropMarks(left, top, sp.coverW, sp.coverH),
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
