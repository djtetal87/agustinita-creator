part of 'agenda_builder.dart';

// Plantilla "Cumpleaños / libro de firmas". Todas las páginas se adaptan al
// alto/ancho disponible (Expanded + LayoutBuilder) para A5, media carta y A6.

extension BirthdayPagesExt on AgendaBuilder {
  pw.TextStyle get _bdayText => pw.TextStyle(font: f.regular, fontSize: 7.5, color: PdfColors.grey800);

  /// Pie de página: deja sitio al número de página.
  pw.Widget get _bdayFoot => pw.SizedBox(height: 5 * mm);

  pw.Widget _bdayBody(PlannerPage p) {
    switch (p.kind) {
      case SectionKind.bdayWelcome:
        return pw.Column(children: [
          pw.SizedBox(height: 3 * mm),
          _title('Bienvenidos', size: 22),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Los ________ años de ____________________',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: f.bold, fontSize: 8.5, color: s.titleFg)),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Fecha: ______________    Lugar: ______________________',
              textAlign: pw.TextAlign.center, style: _bdayText),
          pw.SizedBox(height: 4 * mm),
          pw.Expanded(child: _photoFrame('Foto del festejado', radiusMm: 6)),
          _bdayFoot,
        ]);

      case SectionKind.bdayInstructions:
        const steps = [
          'Escribe tu nombre en la lista de invitados.',
          'Elige una cartita y déjale un deseo.',
          'Escribe un mensaje o dedicatoria.',
          'Cuenta un recuerdo o anécdota.',
          'Deja un consejo y tus predicciones.',
          'Pega una foto de la fiesta.',
          '¡Firma y disfruta!',
        ];
        return pw.Column(children: [
          _title('Cómo usar este libro'),
          pw.SizedBox(height: 2 * mm),
          pw.Expanded(child: pw.Column(children: [
            for (var i = 0; i < steps.length; i++)
              pw.Expanded(child: pw.Row(children: [
                pw.Container(
                  width: 6.5 * mm, height: 6.5 * mm,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: s.accent),
                  child: pw.Text('${i + 1}', style: pw.TextStyle(font: f.bold, fontSize: 8, color: PdfColors.white)),
                ),
                pw.SizedBox(width: 3 * mm),
                pw.Expanded(child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text(steps[i], style: pw.TextStyle(font: f.regular, fontSize: 8, color: PdfColors.grey800)))),
              ])),
          ])),
          _bdayFoot,
        ]);

      case SectionKind.bdayGuests:
        const cols = ['N.°', 'Nombre', 'Firma'];
        const fx = [0.45, 2.2, 1.7];
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Lista de invitados'),
          pw.SizedBox(height: 1 * mm),
          pw.Expanded(child: pw.LayoutBuilder(builder: (ctx, c) {
            final avail = (c?.maxHeight ?? 0) / mm - 6 - 5; // encabezado + pie
            final n = (avail / 7.5).floor().clamp(1, 40);
            final rowH = avail / n;
            return pw.Column(children: [
              _tableHeader(cols, flex: fx),
              for (var r = 0; r < n; r++)
                pw.Container(
                  height: rowH * mm,
                  decoration: pw.BoxDecoration(
                    color: r.isOdd ? s.titleBg : PdfColors.white,
                    border: pw.Border(bottom: pw.BorderSide(color: s.rule, width: 0.2)),
                  ),
                  child: pw.Row(children: [
                    for (var i = 0; i < cols.length; i++)
                      pw.Expanded(
                        flex: (fx[i] * 10).round(),
                        child: pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: i == 0 ? pw.EdgeInsets.only(left: 1.5 * mm) : null,
                          decoration: i == 0 ? null : pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: s.rule, width: 0.2))),
                          child: i == 0 ? pw.Text('${p.index * n + r + 1}', style: _small) : null,
                        ),
                      ),
                  ]),
                ),
            ]);
          })),
          _bdayFoot,
        ]);

      case SectionKind.bdayWishes:
        return pw.Column(children: [
          _title('Cartitas de deseos'),
          pw.SizedBox(height: 2 * mm),
          pw.Expanded(child: pw.Column(children: [
            pw.Expanded(child: _wishCard()),
            pw.SizedBox(height: 3 * mm),
            pw.Expanded(child: _wishCard()),
          ])),
          _bdayFoot,
        ]);

      case SectionKind.bdayMessages:
        return pw.Column(children: [
          _title('Mensajes y dedicatorias'),
          pw.SizedBox(height: 2 * mm),
          _ruled(8),
          _nameSignRow(),
          _bdayFoot,
        ]);

      case SectionKind.bdayMemories:
        return pw.Column(children: [
          _title('Recuerdos y anécdotas'),
          for (final h in ['Te conocí cuando…', 'Nuestro mejor recuerdo…', 'Algo que nunca olvidaré…'])
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _subtitle(h),
              _ruled(7),
            ])),
          _inlineLine('De:'),
          _bdayFoot,
        ]);

      case SectionKind.bdayAdvice:
        const predictions = [
          'Viaja a un lugar nuevo',
          'Cambia de look',
          'Se enamora / sigue enamorado(a)',
          'Cambia de trabajo o estudios',
          'Adopta una mascota',
          'Cumple un sueño',
        ];
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Consejos y predicciones'),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _subtitle('Mi consejo para este año'),
            _ruled(7),
          ])),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _subtitle('En 5 años te veo…'),
            _ruled(7),
          ])),
          _subtitle('Predigo que este año…'),
          pw.Row(children: [
            pw.Expanded(child: pw.SizedBox()),
            pw.Container(width: 11 * mm, child: pw.Center(child: pw.Text('Sí', style: _hdr))),
            pw.Container(width: 11 * mm, child: pw.Center(child: pw.Text('No', style: _hdr))),
          ]),
          for (final t in predictions)
            pw.Container(
              height: 6.5 * mm,
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: s.rule, width: 0.25))),
              child: pw.Row(children: [
                pw.Expanded(child: pw.Text(t, style: pw.TextStyle(font: f.regular, fontSize: 7, color: PdfColors.grey800))),
                for (var k = 0; k < 2; k++)
                  pw.Container(
                    width: 11 * mm,
                    alignment: pw.Alignment.center,
                    child: pw.Container(
                      width: 3.4 * mm, height: 3.4 * mm,
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: s.accent, width: 0.6), borderRadius: pw.BorderRadius.circular(0.8 * mm)),
                    ),
                  ),
              ]),
            ),
          _inlineLine('De:'),
          _bdayFoot,
        ]);

      case SectionKind.bdayPhotos:
        final mode = p.index % 3;
        pw.Widget cell({double captionMm = 6}) => pw.Padding(
              padding: pw.EdgeInsets.all(1.2 * mm),
              child: pw.Column(children: [
                pw.Expanded(child: _photoFrame('', radiusMm: 1.5, corners: true)),
                pw.Container(height: captionMm * mm, alignment: pw.Alignment.bottomCenter, child: _rule()),
              ]),
            );
        pw.Widget layout;
        if (mode == 0) {
          layout = pw.Column(children: [pw.Expanded(child: cell())]);
        } else if (mode == 1) {
          layout = pw.Column(children: [pw.Expanded(child: cell()), pw.Expanded(child: cell())]);
        } else {
          layout = pw.Column(children: [
            for (var r = 0; r < 2; r++)
              pw.Expanded(child: pw.Row(children: [
                pw.Expanded(child: cell(captionMm: 5)),
                pw.Expanded(child: cell(captionMm: 5)),
              ])),
          ]);
        }
        return pw.Column(children: [
          _title('Fotografías de la celebración'),
          pw.SizedBox(height: 1 * mm),
          pw.Expanded(child: layout),
          _bdayFoot,
        ]);

      case SectionKind.bdayClosing:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Gracias por venir'),
          _subtitle('Mensaje del festejado'),
          pw.Expanded(flex: 5, child: _ruledFill(7.5)),
          _subtitle('Foto grupal'),
          pw.Expanded(flex: 6, child: _photoFrame('', radiusMm: 3, corners: true)),
          _bdayFoot,
        ]);

      case SectionKind.bdayFutureLetter:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Carta al futuro'),
          if (p.index == 0) ...[
            pw.SizedBox(height: 2 * mm),
            pw.Text('Ábrela en tu cumpleaños número ________', style: _bdayText),
            pw.SizedBox(height: 2.5 * mm),
            pw.Text('Fecha en que se escribió: ______________________', style: _bdayText),
            pw.SizedBox(height: 1 * mm),
          ],
          pw.Expanded(child: _ruledFill(8)),
          pw.SizedBox(height: 2 * mm),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Container(
              width: 26 * mm, height: 16 * mm,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: s.frame, width: 0.6), borderRadius: pw.BorderRadius.circular(1.5 * mm)),
              child: pw.Column(children: [_envelopeFlap(8)]),
            ),
            pw.SizedBox(width: 3 * mm),
            pw.Expanded(child: _inlineLine('Sellado por:')),
          ]),
          _bdayFoot,
        ]);

      default:
        return pw.SizedBox();
    }
  }

  /// Rayado que llena el espacio (sin Expanded propio: se envuelve afuera).
  pw.Widget _ruledFill(double stepMm) => pw.LayoutBuilder(builder: (ctx, c) {
        final n = ((c?.maxHeight ?? 0) / (stepMm * mm)).floor().clamp(0, 40);
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            for (var i = 0; i < n; i++)
              pw.Container(height: stepMm * mm, alignment: pw.Alignment.bottomCenter, child: _rule()),
          ],
        );
      });

  pw.Widget _nameSignRow() => pw.Row(children: [
        pw.Expanded(flex: 3, child: _inlineLine('Nombre:')),
        pw.SizedBox(width: 4 * mm),
        pw.Expanded(flex: 2, child: _inlineLine('Firma:')),
      ]);

  /// Solapa de sobre: banda de color con borde inferior redondeado y un sello.
  pw.Widget _envelopeFlap(double hMm) => pw.Container(
        height: hMm * mm,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: s.titleBg,
          borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(hMm * 0.9 * mm)),
        ),
        child: pw.Container(
          width: 3.6 * mm, height: 3.6 * mm,
          decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: s.accent),
        ),
      );

  /// Cartita: sobre con solapa arriba, "Para", "Te deseo…" y "Con cariño".
  pw.Widget _wishCard() => pw.Container(
        padding: pw.EdgeInsets.fromLTRB(3 * mm, 2.5 * mm, 3 * mm, 1 * mm),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: s.frame, width: 0.6),
          borderRadius: pw.BorderRadius.circular(3 * mm),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _envelopeFlap(6),
          _inlineLine('Para:'),
          pw.Text('Te deseo…', style: _lbl),
          pw.Expanded(child: _ruledFill(6.5)),
          _inlineLine('Con cariño:'),
        ]),
      );

  /// Recuadro de foto; con [corners] lleva esquineros (L) en color de acento.
  pw.Widget _photoFrame(String hint, {double radiusMm = 3, bool corners = false}) {
    pw.Widget corner(bool top, bool left) {
      const len = 5.0, th = 0.9;
      return pw.Positioned(
        left: left ? 1.5 * mm : null,
        right: left ? null : 1.5 * mm,
        top: top ? 1.5 * mm : null,
        bottom: top ? null : 1.5 * mm,
        child: pw.SizedBox(
          width: len * mm, height: len * mm,
          child: pw.Stack(children: [
            pw.Positioned(
              left: left ? 0 : null, right: left ? null : 0, top: top ? 0 : null, bottom: top ? null : 0,
              child: pw.Container(width: len * mm, height: th, color: s.accent),
            ),
            pw.Positioned(
              left: left ? 0 : null, right: left ? null : 0, top: top ? 0 : null, bottom: top ? null : 0,
              child: pw.Container(width: th, height: len * mm, color: s.accent),
            ),
          ]),
        ),
      );
    }

    return pw.Stack(fit: pw.StackFit.expand, children: [
      pw.Container(
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: s.frame, width: 0.8),
          borderRadius: pw.BorderRadius.circular(radiusMm * mm),
        ),
        child: hint.isEmpty ? null : pw.Text(hint, style: _small),
      ),
      if (corners) ...[corner(true, true), corner(true, false), corner(false, true), corner(false, false)],
    ]);
  }
}
