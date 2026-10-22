part of 'agenda_builder.dart';

// Diseños de cada sección del planner. Comparte helpers con AgendaBuilder.

const _monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
const _dowShort = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _dowLong = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

String _d2(int n) => n.toString().padLeft(2, '0');

extension PlannerPagesExt on AgendaBuilder {
  // ---------- helpers ----------
  pw.TextStyle get _lbl => pw.TextStyle(font: f.regular, fontSize: 6.5, color: s.titleFg);
  pw.TextStyle get _small => pw.TextStyle(font: f.regular, fontSize: 5.5, color: PdfColors.grey700);
  pw.TextStyle get _hdr => pw.TextStyle(font: f.bold, fontSize: 6, color: s.titleFg);

  pw.Widget _tableHeader(List<String> cols, {List<double>? flex}) => pw.Container(
        decoration: pw.BoxDecoration(color: s.titleBg, borderRadius: pw.BorderRadius.circular(1.5 * mm)),
        padding: pw.EdgeInsets.symmetric(horizontal: 1.5 * mm, vertical: 1.2 * mm),
        child: pw.Row(children: [
          for (var i = 0; i < cols.length; i++)
            pw.Expanded(flex: ((flex?[i] ?? 1) * 10).round(), child: pw.Text(cols[i], style: _hdr)),
        ]),
      );

  /// Tabla simple que llena el espacio: encabezado + filas vacías.
  pw.Widget _fillTable(List<String> cols, {List<double>? flex, double rowMm = 8}) => pw.Expanded(
        child: pw.LayoutBuilder(builder: (ctx, c) {
          final n = (((c?.maxHeight ?? 0) / mm - 7) / rowMm).floor().clamp(1, 40);
          return pw.Column(children: [
            _tableHeader(cols, flex: flex),
            for (var r = 0; r < n; r++)
              pw.Container(
                height: rowMm * mm,
                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: s.rule, width: 0.3))),
                child: pw.Row(children: [
                  for (var i = 0; i < cols.length; i++)
                    pw.Expanded(
                      flex: ((flex?[i] ?? 1) * 10).round(),
                      child: pw.Container(
                        decoration: i == 0 ? null : pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: s.rule, width: 0.2))),
                      ),
                    ),
                ]),
              ),
          ]);
        }),
      );

  pw.Widget _subtitle(String t) => pw.Padding(
        padding: pw.EdgeInsets.only(top: 2.5 * mm, bottom: 1 * mm),
        child: pw.Text(t, style: pw.TextStyle(font: f.bold, fontSize: 7, color: s.titleFg)),
      );

  pw.Widget _checkRows(int n, {double h = 8, bool priority = false}) => pw.Column(children: [
        for (var i = 0; i < n; i++)
          pw.Container(
            height: h * mm,
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              if (priority)
                pw.Container(width: 7 * mm, margin: pw.EdgeInsets.only(right: 1.5 * mm, bottom: 0.4 * mm),
                    child: pw.Row(children: [for (var k = 0; k < 3; k++)
                      pw.Container(width: 1.6 * mm, height: 1.6 * mm, margin: pw.EdgeInsets.only(right: 0.5 * mm),
                          decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, border: pw.Border.all(color: s.accent, width: 0.4)))])),
              pw.Container(width: 3.6 * mm, height: 3.6 * mm, margin: pw.EdgeInsets.only(right: 2.5 * mm, bottom: 0.4 * mm),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: s.accent, width: 0.6), borderRadius: pw.BorderRadius.circular(0.8 * mm))),
              pw.Expanded(child: _rule()),
            ]),
          ),
      ]);

  pw.Widget _fillCheck({double h = 8, bool priority = false}) => pw.Expanded(
        child: pw.LayoutBuilder(builder: (ctx, c) => _checkRows(((c?.maxHeight ?? 0) / (h * mm)).floor().clamp(1, 40), h: h, priority: priority)),
      );

  // ---------- calendario mensual (grilla) ----------
  pw.Widget _monthGrid(int year, int month, {required double cellH, bool withHolidays = true, bool big = true}) {
    final hs = withHolidays ? chileHolidays(year) : <Holiday>[];
    final first = DateTime(year, month, 1);
    final days = DateTime(year, month + 1, 0).day;
    final offset = (first.weekday + 6) % 7;
    final cells = <int?>[...List.filled(offset, null), for (var d = 1; d <= days; d++) d];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final rows = cells.length ~/ 7;
    return pw.Column(children: [
      pw.Row(children: [for (var i = 0; i < 7; i++)
        pw.Expanded(child: pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 0.8 * mm),
          decoration: pw.BoxDecoration(color: s.titleBg),
          child: pw.Center(child: pw.Text(big ? _dowLong[i].substring(0, 3) : _dowShort[i],
              style: pw.TextStyle(font: f.bold, fontSize: big ? 6 : 4.5, color: s.titleFg)))))]),
      for (var r = 0; r < rows; r++)
        pw.Row(children: [for (var c = 0; c < 7; c++)
          pw.Expanded(child: pw.Container(
            height: cellH * mm,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: s.rule, width: 0.25)),
            padding: pw.EdgeInsets.all(0.8 * mm),
            alignment: pw.Alignment.topLeft,
            child: cells[r * 7 + c] == null ? null : pw.Text('${cells[r * 7 + c]}',
                style: pw.TextStyle(font: f.bold, fontSize: big ? 6 : 4.5,
                    color: (c == 6 || isHoliday(hs, DateTime(year, month, cells[r * 7 + c]!))) ? s.accent : PdfColors.grey800)),
          ))]),
    ]);
  }

  // ---------- render ----------
  pw.Widget plannerBody(PlannerPage p) {
    final y = p.year, m = p.month;
    switch (p.kind) {
      case SectionKind.owner:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Esta agenda pertenece a'),
          pw.SizedBox(height: 4 * mm),
          for (final l in ['Nombre:', 'Teléfono:', 'Correo:', 'Dirección:', 'En caso de emergencia avisar a:', 'Mi frase del año:'])
            _labelLine(l),
        ]);

      case SectionKind.yearCalendar:
        return pw.Column(children: [
          _title('Calendario $y'),
          pw.SizedBox(height: 1 * mm),
          pw.Text('Feriados de Chile en color', style: _small),
          pw.SizedBox(height: 2 * mm),
          pw.Expanded(child: pw.GridView(
            crossAxisCount: 3, childAspectRatio: 0.95, crossAxisSpacing: 2.5 * mm, mainAxisSpacing: 2 * mm,
            children: [for (var mm2 = 1; mm2 <= 12; mm2++)
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(_monthNames[mm2 - 1], style: pw.TextStyle(font: f.bold, fontSize: 5, color: s.titleFg)),
                pw.SizedBox(height: 0.6 * mm),
                _monthGrid(y, mm2, cellH: 3.2, big: false),
              ])],
          )),
        ]);

      case SectionKind.holidaysList:
        final hs = chileHolidays(y);
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Feriados $y'),
          pw.SizedBox(height: 3 * mm),
          for (final h in hs)
            pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: 1.3 * mm),
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: s.rule, width: 0.25))),
              child: pw.Row(children: [
                pw.Container(width: 22 * mm, child: pw.Text('${_dowLong[h.date.weekday - 1].substring(0, 3)} ${_d2(h.date.day)} ${_monthNames[h.date.month - 1].substring(0, 3)}',
                    style: pw.TextStyle(font: f.bold, fontSize: 6, color: s.accent))),
                pw.Expanded(child: pw.Text(h.name, style: _lbl)),
              ]),
            ),
          pw.SizedBox(height: 3 * mm),
          pw.Text('Feriados por elecciones o censo no incluidos. Verificar en feriados.cl', style: _small),
        ]);

      case SectionKind.birthdays:
        final from = p.index == 0 ? 1 : 7;
        return pw.Column(children: [
          _title('Cumpleaños y fechas importantes'),
          pw.SizedBox(height: 2 * mm),
          pw.Expanded(child: pw.GridView(
            crossAxisCount: 2, childAspectRatio: 1.1, crossAxisSpacing: 3 * mm, mainAxisSpacing: 2 * mm,
            children: [for (var mm2 = from; mm2 < from + 6; mm2++)
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(_monthNames[mm2 - 1], style: pw.TextStyle(font: f.bold, fontSize: 6.5, color: s.titleFg)),
                pw.SizedBox(height: 1 * mm),
                for (var r = 0; r < 6; r++) pw.Container(height: 6.5 * mm, alignment: pw.Alignment.bottomCenter, child: _rule()),
              ])],
          )),
        ]);

      case SectionKind.yearGoals:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Objetivos del año $y'),
          _subtitle('Mis metas principales'),
          _checkRows(6, h: 9),
          _subtitle('Qué necesito para lograrlas'),
          _ruled(8, count: 5),
          _subtitle('Cómo me voy a premiar'),
          _ruled(8, count: 3),
        ]);

      case SectionKind.monthDivider:
        // Página de arte: el fondo lo pone _half (separatorArt). Aquí solo el nombre del mes.
        return pw.Column(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 8 * mm, vertical: 3 * mm),
            decoration: pw.BoxDecoration(color: PdfColor(1, 1, 1, 0.85), borderRadius: pw.BorderRadius.circular(5 * mm)),
            child: pw.Column(children: [
              pw.Text(_monthNames[m - 1], style: pw.TextStyle(font: f.display, fontSize: 24, color: s.titleFg)),
              pw.Text('$y', style: pw.TextStyle(font: f.medium, fontSize: 9, color: s.titleFg)),
            ]),
          ),
          pw.SizedBox(height: 6 * mm),
        ]);

      case SectionKind.monthPlan:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('${_monthNames[m - 1]} $y'),
          pw.SizedBox(height: 3 * mm),
          _monthGrid(y, m, cellH: 17),
          _subtitle('Notas del mes'),
          _ruled(8),
        ]);

      case SectionKind.monthGoals:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Metas de ${_monthNames[m - 1]}'),
          _subtitle('Objetivos del mes'),
          _checkRows(5, h: 9),
          _subtitle('Pasos para lograrlos'),
          _ruled(8, count: 6),
          _subtitle('Prioridad n.º 1'),
          _box(22),
        ]);

      case SectionKind.finance:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Finanzas · ${_monthNames[m - 1]}'),
          _subtitle('Ingresos'),
          _smallTable(['Fecha', 'Detalle', 'Monto'], [1, 2.5, 1.2], 4),
          _subtitle('Gastos'),
          _smallTable(['Fecha', 'Detalle', 'Monto'], [1, 2.5, 1.2], 7),
          _subtitle('Pagos pendientes'),
          _smallTable(['Vence', 'Qué', 'Monto', '✓'], [1, 2.2, 1.2, 0.5], 4),
          pw.SizedBox(height: 2 * mm),
          pw.Row(children: [
            pw.Expanded(child: pw.Text('Total ingresos: \$ ________', style: _lbl)),
            pw.Expanded(child: pw.Text('Total gastos: \$ ________', style: _lbl)),
          ]),
          pw.SizedBox(height: 1.5 * mm),
          pw.Text('Ahorro del mes: \$ ________    Ahorro acumulado: \$ ________', style: pw.TextStyle(font: f.bold, fontSize: 6.5, color: s.titleFg)),
        ]);

      case SectionKind.habits:
        final days = DateTime(y, m + 1, 0).day;
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Hábitos · ${_monthNames[m - 1]}'),
          pw.SizedBox(height: 1 * mm),
          pw.Text('Actividad física, autocuidado y hábitos. Marca cada día que lo cumplas.', style: _small),
          pw.SizedBox(height: 2 * mm),
          pw.Expanded(child: pw.LayoutBuilder(builder: (ctx, c) {
            final rows = (((c?.maxHeight ?? 0) / mm - 6) / 9).floor().clamp(3, 12);
            final labelW = 26.0;
            return pw.Column(children: [
              pw.Row(children: [
                pw.Container(width: labelW * mm, child: pw.Text('Hábito', style: _hdr)),
                for (var d = 1; d <= days; d++)
                  pw.Expanded(child: pw.Center(child: pw.Text('$d', style: pw.TextStyle(font: f.regular, fontSize: 3.6, color: PdfColors.grey700)))),
              ]),
              for (var r = 0; r < rows; r++)
                pw.Container(
                  height: 9 * mm,
                  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: s.rule, width: 0.3))),
                  child: pw.Row(children: [
                    pw.Container(width: labelW * mm),
                    for (var d = 1; d <= days; d++)
                      pw.Expanded(child: pw.Container(decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: s.rule, width: 0.15))))),
                  ]),
                ),
            ]);
          })),
        ]);

      case SectionKind.weekly:
        final w = p.weekStart!;
        final half = p.index % 2; // 0: lun-mié · 1: jue-dom + tareas
        final days = half == 0 ? [0, 1, 2] : [3, 4, 5, 6];
        final end = w.add(const Duration(days: 6));
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Semana ${_d2(w.day)} ${_monthNames[w.month - 1].substring(0, 3)} – ${_d2(end.day)} ${_monthNames[end.month - 1].substring(0, 3)}'),
          pw.SizedBox(height: 2 * mm),
          pw.Expanded(child: pw.Column(children: [
            for (final d in days)
              pw.Expanded(child: pw.Container(
                margin: pw.EdgeInsets.only(bottom: 1.5 * mm),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: s.frame, width: 0.5), borderRadius: pw.BorderRadius.circular(2 * mm)),
                child: pw.Row(children: [
                  pw.Container(
                    width: 13 * mm,
                    decoration: pw.BoxDecoration(color: s.titleBg, borderRadius: pw.BorderRadius.horizontal(left: pw.Radius.circular(2 * mm))),
                    child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                      pw.Text('${w.add(Duration(days: d)).day}', style: pw.TextStyle(font: f.display, fontSize: 11, color: s.titleFg)),
                      pw.Text(_dowLong[d].substring(0, 3), style: pw.TextStyle(font: f.regular, fontSize: 5, color: s.titleFg)),
                    ]),
                  ),
                  pw.Expanded(child: pw.Padding(padding: pw.EdgeInsets.fromLTRB(2 * mm, 0, 2 * mm, 0),
                      child: pw.LayoutBuilder(builder: (ctx, c) => pw.Column(children: [
                        for (var i = 0; i < ((c?.maxHeight ?? 0) / (6.5 * mm)).floor(); i++)
                          pw.Container(height: 6.5 * mm, alignment: pw.Alignment.bottomCenter, child: _rule()),
                      ])))),
                ]),
              )),
            if (half == 1)
              pw.Container(
                height: 30 * mm,
                padding: pw.EdgeInsets.all(2 * mm),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: s.frame, width: 0.5), borderRadius: pw.BorderRadius.circular(2 * mm)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Tareas de la semana', style: _hdr),
                  _checkRows(3, h: 7),
                ]),
              ),
          ])),
        ]);

      case SectionKind.schedule:
        final w = p.weekStart!;
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Horario · semana del ${_d2(w.day)} ${_monthNames[w.month - 1].substring(0, 3)}'),
          pw.SizedBox(height: 2 * mm),
          pw.Expanded(child: pw.LayoutBuilder(builder: (ctx, c) {
            const startH = 8, endH = 21; // 8:00 – 21:00, bloques de 30 min
            final slots = (endH - startH) * 2;
            final rowH = ((c?.maxHeight ?? 0) - 6 * mm) / slots;
            return pw.Column(children: [
              pw.Row(children: [
                pw.Container(width: 11 * mm),
                for (var d = 0; d < 7; d++)
                  pw.Expanded(child: pw.Container(
                    decoration: pw.BoxDecoration(color: s.titleBg),
                    padding: pw.EdgeInsets.symmetric(vertical: 0.8 * mm),
                    child: pw.Center(child: pw.Text('${_dowLong[d].substring(0, 3)} ${w.add(Duration(days: d)).day}', style: pw.TextStyle(font: f.bold, fontSize: 5, color: s.titleFg))),
                  )),
              ]),
              for (var i = 0; i < slots; i++)
                pw.Container(
                  height: rowH,
                  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: s.rule, width: i.isEven ? 0.15 : 0.35))),
                  child: pw.Row(children: [
                    pw.Container(width: 11 * mm, alignment: pw.Alignment.centerLeft,
                        child: i.isEven ? pw.Text('${startH + i ~/ 2}:00', style: pw.TextStyle(font: f.regular, fontSize: 4.5, color: PdfColors.grey700)) : null),
                    for (var d = 0; d < 7; d++)
                      pw.Expanded(child: pw.Container(decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: s.rule, width: 0.2))))),
                  ]),
                ),
            ]);
          })),
        ]);

      case SectionKind.daily:
        final d = p.weekStart!.add(Duration(days: p.index));
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('${_dowLong[d.weekday - 1]} ${d.day} de ${_monthNames[d.month - 1]}'),
          pw.SizedBox(height: 2 * mm),
          pw.Expanded(child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(flex: 11, child: pw.Column(children: [
              for (var h = 7; h <= 21; h++)
                pw.Expanded(child: pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: s.rule, width: 0.3))),
                  child: pw.Row(children: [
                    pw.Container(width: 9 * mm, child: pw.Text('$h:00', style: pw.TextStyle(font: f.regular, fontSize: 5, color: PdfColors.grey700))),
                  ]),
                )),
            ])),
            pw.SizedBox(width: 3 * mm),
            pw.Expanded(flex: 8, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Prioridades', style: _hdr),
              _checkRows(3, h: 7),
              pw.SizedBox(height: 2 * mm),
              pw.Text('Tareas', style: _hdr),
              _checkRows(6, h: 7),
              pw.SizedBox(height: 2 * mm),
              pw.Text('Notas', style: _hdr),
              _ruled(7, count: 5),
            ])),
          ])),
        ]);

      case SectionKind.meetings:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Reuniones y compromisos · ${_monthNames[m - 1]}'),
          pw.SizedBox(height: 2 * mm),
          _fillTable(['Fecha', 'Hora', 'Reunión / compromiso', 'Recordatorio'], flex: [0.9, 0.7, 2.2, 1.5], rowMm: 9),
        ]);

      case SectionKind.monthBalance:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Balance de ${_monthNames[m - 1]}'),
          _subtitle('Objetivos cumplidos'),
          _checkRows(5, h: 8),
          _subtitle('Pendientes para el próximo mes'),
          _checkRows(4, h: 8),
          _subtitle('Lo mejor del mes'),
          _ruled(8, count: 3),
          _subtitle('Qué haría distinto'),
          _ruled(8, count: 3),
        ]);

      case SectionKind.tasks:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Tareas pendientes'),
          pw.SizedBox(height: 1 * mm),
          pw.Text('Prioridad: ●○○ baja · ●●○ media · ●●● alta', style: _small),
          pw.SizedBox(height: 2 * mm),
          _fillCheck(h: 8.5, priority: true),
        ]);

      case SectionKind.patients:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Pacientes'),
          pw.SizedBox(height: 2 * mm),
          _fillTable(['Paciente', 'Contacto', 'Motivo / evaluación', 'Informe', 'Día y hora'], flex: [1.5, 1.2, 1.8, 0.8, 1.1], rowMm: 12),
        ]);

      case SectionKind.sessions:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Registro de sesiones'),
          pw.SizedBox(height: 1 * mm),
          pw.Text('Estado: A asistió · I inasistencia · R reagendada', style: _small),
          pw.SizedBox(height: 2 * mm),
          _fillTable(['Fecha', 'Paciente', 'Sesión n.º', 'Estado', 'Observaciones'], flex: [0.9, 1.6, 0.8, 0.7, 2], rowMm: 8.5),
        ]);

      case SectionKind.projects:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Proyectos y tareas laborales'),
          pw.SizedBox(height: 2 * mm),
          _fillTable(['Proyecto / tarea', 'Pasos', 'Fecha límite', 'Estado'], flex: [1.6, 2, 0.9, 0.8], rowMm: 11),
        ]);

      case SectionKind.classes:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Horario de clases'),
          pw.SizedBox(height: 2 * mm),
          pw.Expanded(child: pw.LayoutBuilder(builder: (ctx, c) {
            const blocks = 9;
            final rowH = ((c?.maxHeight ?? 0) - 6 * mm) / blocks;
            return pw.Column(children: [
              pw.Row(children: [
                pw.Container(width: 12 * mm),
                for (var d = 0; d < 5; d++)
                  pw.Expanded(child: pw.Container(decoration: pw.BoxDecoration(color: s.titleBg), padding: pw.EdgeInsets.symmetric(vertical: 0.8 * mm),
                      child: pw.Center(child: pw.Text(_dowLong[d], style: pw.TextStyle(font: f.bold, fontSize: 5.5, color: s.titleFg))))),
              ]),
              for (var i = 0; i < blocks; i++)
                pw.Container(
                  height: rowH,
                  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: s.rule, width: 0.3))),
                  child: pw.Row(children: [
                    pw.Container(width: 12 * mm, alignment: pw.Alignment.centerLeft, child: pw.Text('Bloque ${i + 1}', style: _small)),
                    for (var d = 0; d < 5; d++)
                      pw.Expanded(child: pw.Container(decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: s.rule, width: 0.2))))),
                  ]),
                ),
            ]);
          })),
        ]);

      case SectionKind.grades:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title('Registro de evaluaciones'),
          pw.SizedBox(height: 1 * mm),
          pw.Text('Curso: ______________   Asignatura: ______________', style: _lbl),
          pw.SizedBox(height: 2 * mm),
          _fillTable(['Alumno/a', 'Ev. 1', 'Ev. 2', 'Ev. 3', 'Ev. 4', 'Ev. 5', 'Prom.'], flex: [2.4, 0.6, 0.6, 0.6, 0.6, 0.6, 0.7], rowMm: 7),
        ]);

      case SectionKind.notes:
        return pw.Column(children: [_title('Notas y apuntes'), pw.SizedBox(height: 2 * mm), _ruled(8)]);

      case SectionKind.ideas:
        return pw.Column(children: [_title('Ideas'), pw.SizedBox(height: 2 * mm), pw.Expanded(child: _customLayout(CustomLayout.dotted))]);

      // ---------- agenda infantil ----------
      case SectionKind.kidHandwriting:
        return pw.Column(children: [_title('Mi caligrafía'), pw.SizedBox(height: 2 * mm), _handwritingFill()]);
      case SectionKind.kidDrawWrite:
        return pw.Column(children: [_title('Dibujo y escribo'), pw.SizedBox(height: 3 * mm), _box(60), pw.SizedBox(height: 2 * mm), _handwritingFill()]);
      case SectionKind.kidFeelings:
        return _pageBody(const PageDef(PageKind.feelings), 0, bare: true);
      case SectionKind.kidTherapyTasks:
        return _pageBody(const PageDef(PageKind.therapyTasks), 0, bare: true);
      case SectionKind.kidHomework:
        return pw.Column(children: [_title('Desarrollo de mi tarea'), pw.SizedBox(height: 2 * mm), _ruled(12)]);
      case SectionKind.kidSavings:
        return _pageBody(const PageDef(PageKind.savings), 0, bare: true);
      case SectionKind.kidAchievements:
        return _pageBody(const PageDef(PageKind.achievements), 0, bare: true);
      case SectionKind.kidCreative:
        return _pageBody(const PageDef(PageKind.creative), 0, bare: true);
      case SectionKind.custom:
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _title(p.title ?? ''),
          pw.SizedBox(height: 3 * mm),
          _customLayout(p.layout ?? CustomLayout.ruled),
        ]);
      case SectionKind.namePage:
        return _pageBody(const PageDef(PageKind.namePage), 0, bare: true);
    }
  }

  pw.Widget _smallTable(List<String> cols, List<double> flex, int rows) => pw.Column(children: [
        _tableHeader(cols, flex: flex),
        for (var r = 0; r < rows; r++)
          pw.Container(
            height: 6.5 * mm,
            decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: s.rule, width: 0.3))),
            child: pw.Row(children: [for (var i = 0; i < cols.length; i++)
              pw.Expanded(flex: (flex[i] * 10).round(), child: pw.Container(
                  decoration: i == 0 ? null : pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: s.rule, width: 0.2)))))]),
          ),
      ]);
}
