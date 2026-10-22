/// Catálogo de secciones de agenda/planner, plantillas por tipo de clienta
/// y generación de la lista de páginas.
import '../specs.dart' show CustomLayout, CustomPage;

enum SectionKind {
  owner, // Datos personales
  yearCalendar, // Calendario anual (con feriados de Chile)
  holidaysList, // Lista de feriados del año
  birthdays, // Cumpleaños y fechas importantes
  yearGoals, // Objetivos del año
  monthDivider, // Separador de mes (arte completo + personaje)
  monthPlan, // Planificación mensual (grilla)
  monthGoals, // Objetivos y metas del mes
  finance, // Ingresos, gastos, pagos pendientes, ahorros
  habits, // Hábitos, actividad física y autocuidado (grilla 31 días)
  weekly, // Planificación semanal (2 páginas por semana)
  schedule, // Horario por bloques (semana, 7 columnas)
  daily, // Espacio diario (bloques de hora + tareas) — 1 página por día
  meetings, // Reuniones, compromisos y recordatorios
  monthBalance, // Balance mensual
  tasks, // Tareas pendientes y prioridades
  patients, // Organización de pacientes
  sessions, // Registro de sesiones / inasistencias / reagendamientos
  projects, // Seguimiento de tareas laborales y proyectos
  classes, // Horario de clases / cursos (profesora)
  grades, // Registro de evaluaciones (profesora)
  notes, // Notas y apuntes (rayado)
  ideas, // Ideas y anotaciones libres (punteado)
  // páginas de la agenda infantil
  kidHandwriting, kidDrawWrite, kidFeelings, kidTherapyTasks, kidHomework, kidSavings, kidAchievements, kidCreative,
  custom, // Página extra definida por el usuario (título + pauta)
  namePage, // Página final con nombre, frase y personaje
}

/// Dónde se ubica la sección en la estructura.
enum Placement { front, perMonth, perWeek, back }

class SectionDef {
  final SectionKind kind;
  final String label;
  final String hint;
  final Placement placement;
  final int defaultPages; // páginas por unidad (por mes/semana si aplica)
  final bool artOnly; // página sin pauta: lleva el personaje grande
  const SectionDef(this.kind, this.label, this.hint, this.placement, this.defaultPages, {this.artOnly = false});
}

const sectionCatalog = <SectionDef>[
  SectionDef(SectionKind.owner, 'Datos personales', '"Esta agenda pertenece a…"', Placement.front, 1),
  SectionDef(SectionKind.yearCalendar, 'Calendario anual', '12 meses con feriados de Chile marcados', Placement.front, 1),
  SectionDef(SectionKind.holidaysList, 'Lista de feriados', 'Feriados de Chile del año', Placement.front, 1),
  SectionDef(SectionKind.birthdays, 'Cumpleaños y fechas importantes', 'Lista por mes', Placement.front, 2),
  SectionDef(SectionKind.yearGoals, 'Objetivos del año', 'Metas anuales', Placement.front, 1),
  SectionDef(SectionKind.monthDivider, 'Separador de mes', 'Arte completo con el personaje y el nombre del mes', Placement.perMonth, 1, artOnly: true),
  SectionDef(SectionKind.monthPlan, 'Planificación mensual', 'Grilla del mes con notas', Placement.perMonth, 1),
  SectionDef(SectionKind.monthGoals, 'Objetivos y metas del mes', 'Metas, pasos y prioridades', Placement.perMonth, 1),
  SectionDef(SectionKind.finance, 'Control de finanzas', 'Ingresos, gastos, pagos pendientes y ahorros', Placement.perMonth, 1),
  SectionDef(SectionKind.habits, 'Hábitos y autocuidado', 'Grilla de 31 días: hábitos, actividad física, autocuidado', Placement.perMonth, 1),
  SectionDef(SectionKind.weekly, 'Planificación semanal', 'Cada semana en 2 páginas (lun–mié / jue–dom + tareas)', Placement.perWeek, 2),
  SectionDef(SectionKind.schedule, 'Horario por bloques', 'Semana en columnas, bloques de 30 o 60 min', Placement.perWeek, 1),
  SectionDef(SectionKind.daily, 'Espacio diario', '1 página por día: horario + tareas (muchas páginas)', Placement.perWeek, 7),
  SectionDef(SectionKind.meetings, 'Reuniones y compromisos', 'Reuniones, compromisos y recordatorios del mes', Placement.perMonth, 1),
  SectionDef(SectionKind.monthBalance, 'Balance mensual', 'Objetivos cumplidos y pendientes', Placement.perMonth, 1),
  SectionDef(SectionKind.tasks, 'Tareas pendientes y prioridades', 'Checklist con prioridad', Placement.back, 4),
  SectionDef(SectionKind.patients, 'Organización de pacientes', 'Ficha: paciente, contacto, motivo, evaluaciones, informes', Placement.back, 6),
  SectionDef(SectionKind.sessions, 'Registro de sesiones', 'Fecha, paciente, asistió / inasistencia / reagendado', Placement.back, 8),
  SectionDef(SectionKind.projects, 'Tareas laborales y proyectos', 'Proyecto, pasos, fecha límite, estado', Placement.back, 4),
  SectionDef(SectionKind.classes, 'Horario de clases y cursos', 'Horario semanal por curso (profesora)', Placement.back, 2),
  SectionDef(SectionKind.grades, 'Registro de evaluaciones', 'Tabla curso / alumno / notas (profesora)', Placement.back, 6),
  SectionDef(SectionKind.notes, 'Notas y apuntes', 'Páginas rayadas', Placement.back, 8),
  SectionDef(SectionKind.ideas, 'Ideas y anotaciones libres', 'Páginas punteadas', Placement.back, 6),
  SectionDef(SectionKind.kidHandwriting, 'Mi caligrafía', 'Pauta de caligrafía (niños)', Placement.back, 10),
  SectionDef(SectionKind.kidDrawWrite, 'Dibujo y escribo', 'Recuadro + pauta (niños)', Placement.back, 4),
  SectionDef(SectionKind.kidFeelings, 'Cómo me siento hoy', '(niños)', Placement.back, 3),
  SectionDef(SectionKind.kidTherapyTasks, 'Mis tareas del psicólogo', 'Checklist (niños)', Placement.back, 4),
  SectionDef(SectionKind.kidHomework, 'Desarrollo de mi tarea', 'Rayado ancho (niños)', Placement.back, 4),
  SectionDef(SectionKind.kidSavings, 'Mis primeros ahorros', 'Tabla (niños)', Placement.back, 2),
  SectionDef(SectionKind.kidAchievements, 'Mis logros', 'Lista numerada (niños)', Placement.back, 2),
  SectionDef(SectionKind.kidCreative, 'Escritura creativa', '(niños)', Placement.back, 2),
  SectionDef(SectionKind.custom, 'Página extra', 'Definida por el usuario', Placement.back, 1),
  SectionDef(SectionKind.namePage, 'Página del nombre', 'Nombre, frase y personaje al final', Placement.back, 1, artOnly: true),
];

SectionDef sectionDef(SectionKind k) => sectionCatalog.firstWhere((s) => s.kind == k);

/// Selección de una sección en el formulario.
class SectionChoice {
  final SectionKind kind;
  bool enabled;
  int pages; // por unidad
  SectionChoice(this.kind, {this.enabled = true, int? pages}) : pages = pages ?? sectionDef(kind).defaultPages;
  SectionChoice copy() => SectionChoice(kind, enabled: enabled, pages: pages);
}

/// Plantillas por tipo de clienta.
class PlannerTemplate {
  final String id;
  final String label;
  final List<SectionChoice> Function() build;
  const PlannerTemplate(this.id, this.label, this.build);
}

List<SectionChoice> _c(List<SectionKind> on, {Map<SectionKind, int> pages = const {}, List<SectionKind> off = const []}) {
  return [
    for (final k in on) SectionChoice(k, pages: pages[k]),
    for (final k in off) SectionChoice(k, enabled: false),
  ];
}

final plannerTemplates = <PlannerTemplate>[
  PlannerTemplate('psicologa', 'Psicóloga / profesional completa', () => _c([
        SectionKind.owner, SectionKind.yearCalendar, SectionKind.holidaysList, SectionKind.birthdays, SectionKind.yearGoals,
        SectionKind.monthDivider, SectionKind.monthPlan, SectionKind.monthGoals, SectionKind.finance, SectionKind.habits,
        SectionKind.weekly, SectionKind.schedule, SectionKind.meetings, SectionKind.monthBalance,
        SectionKind.tasks, SectionKind.patients, SectionKind.sessions, SectionKind.projects, SectionKind.notes, SectionKind.ideas,
        SectionKind.namePage,
      ], off: [SectionKind.daily])),
  PlannerTemplate('profesora', 'Profesora', () => _c([
        SectionKind.owner, SectionKind.yearCalendar, SectionKind.holidaysList, SectionKind.birthdays, SectionKind.yearGoals,
        SectionKind.monthDivider, SectionKind.monthPlan, SectionKind.monthGoals, SectionKind.weekly, SectionKind.meetings, SectionKind.monthBalance,
        SectionKind.classes, SectionKind.grades, SectionKind.tasks, SectionKind.projects, SectionKind.notes, SectionKind.ideas, SectionKind.namePage,
      ], off: [SectionKind.finance, SectionKind.habits, SectionKind.schedule, SectionKind.daily])),
  PlannerTemplate('regalo', 'Para regalar (básica)', () => _c([
        SectionKind.owner, SectionKind.yearCalendar, SectionKind.birthdays,
        SectionKind.monthDivider, SectionKind.monthPlan, SectionKind.monthGoals, SectionKind.finance, SectionKind.weekly,
        SectionKind.tasks, SectionKind.notes, SectionKind.namePage,
      ], pages: {SectionKind.tasks: 2, SectionKind.notes: 4}, off: [SectionKind.habits, SectionKind.schedule, SectionKind.meetings, SectionKind.monthBalance, SectionKind.ideas])),
  PlannerTemplate('nino', 'Niño / niña (agenda escolar)', () => _c([
        SectionKind.owner, SectionKind.notes, SectionKind.yearCalendar,
        SectionKind.kidHandwriting, SectionKind.kidDrawWrite, SectionKind.kidFeelings, SectionKind.kidTherapyTasks,
        SectionKind.kidHomework, SectionKind.kidSavings, SectionKind.kidAchievements, SectionKind.kidCreative, SectionKind.namePage,
      ], pages: {SectionKind.notes: 4}, off: [SectionKind.birthdays, SectionKind.monthDivider, SectionKind.monthPlan, SectionKind.weekly, SectionKind.tasks, SectionKind.ideas])),
  PlannerTemplate('libre', 'Armar desde cero', () => _c([SectionKind.owner, SectionKind.namePage],
      off: [SectionKind.yearCalendar, SectionKind.holidaysList, SectionKind.birthdays, SectionKind.yearGoals, SectionKind.monthDivider,
            SectionKind.monthPlan, SectionKind.monthGoals, SectionKind.finance, SectionKind.habits, SectionKind.weekly, SectionKind.schedule,
            SectionKind.daily, SectionKind.meetings, SectionKind.monthBalance, SectionKind.tasks, SectionKind.patients, SectionKind.sessions,
            SectionKind.projects, SectionKind.classes, SectionKind.grades, SectionKind.notes, SectionKind.ideas])),
];

/// Una página concreta a dibujar.
class PlannerPage {
  final SectionKind kind;
  final int year;
  final int month; // 1-12 (0 si no aplica)
  final DateTime? weekStart; // lunes de la semana (si aplica)
  final int index; // n° de página dentro de la sección (para variar)
  final String? title; // solo custom
  final CustomLayout? layout; // solo custom
  const PlannerPage(this.kind, {required this.year, this.month = 0, this.weekStart, this.index = 0, this.title, this.layout});
}

/// Lunes de cada semana que toca el mes (sin repetir semanas entre meses:
/// cada semana pertenece al mes donde cae su lunes, salvo la primera del año).
List<DateTime> _weeksOfMonth(int year, int month) {
  final first = DateTime(year, month, 1);
  final last = DateTime(year, month + 1, 0);
  var monday = first.subtract(Duration(days: first.weekday - 1));
  final out = <DateTime>[];
  while (!monday.isAfter(last)) {
    final belongs = monday.month == month || (month == 1 && monday.year < year);
    if (belongs) out.add(monday);
    monday = monday.add(const Duration(days: 7));
  }
  return out;
}

/// Estructura: front → (por cada mes: separador, mensual, metas, finanzas,
/// hábitos, [por semana: semanal, horario, diario], reuniones, balance) → back.
List<PlannerPage> buildPlannerPages({
  required List<SectionChoice> choices,
  required int year,
  int monthsFrom = 1,
  int monthsCount = 12,
  List<CustomPage> custom = const [],
}) {
  final on = {for (final c in choices) if (c.enabled) c.kind: c.pages};
  final order = sectionCatalog.map((s) => s.kind).toList();
  List<SectionKind> of(Placement p) => order.where((k) => on.containsKey(k) && sectionDef(k).placement == p).toList();

  final pages = <PlannerPage>[];
  for (final k in of(Placement.front)) {
    for (var i = 0; i < on[k]!; i++) {
      pages.add(PlannerPage(k, year: year, index: i));
    }
  }
  final perMonth = of(Placement.perMonth);
  final perWeek = of(Placement.perWeek);
  final monthOrder = [SectionKind.monthDivider, SectionKind.monthPlan, SectionKind.monthGoals, SectionKind.finance, SectionKind.habits];
  final monthTail = [SectionKind.meetings, SectionKind.monthBalance];
  for (var m = monthsFrom; m < monthsFrom + monthsCount; m++) {
    final y = year + (m - 1) ~/ 12;
    final mm = (m - 1) % 12 + 1;
    for (final k in monthOrder.where(perMonth.contains)) {
      for (var i = 0; i < on[k]!; i++) {
        pages.add(PlannerPage(k, year: y, month: mm, index: i));
      }
    }
    if (perWeek.isNotEmpty) {
      for (final w in _weeksOfMonth(y, mm)) {
        for (final k in [SectionKind.weekly, SectionKind.schedule, SectionKind.daily].where(perWeek.contains)) {
          final n = k == SectionKind.daily ? 7 : on[k]!;
          for (var i = 0; i < n; i++) {
            pages.add(PlannerPage(k, year: y, month: mm, weekStart: w, index: i));
          }
        }
      }
    }
    for (final k in monthTail.where(perMonth.contains)) {
      for (var i = 0; i < on[k]!; i++) {
        pages.add(PlannerPage(k, year: y, month: mm, index: i));
      }
    }
  }
  for (final k in of(Placement.back)) {
    if (k == SectionKind.namePage) continue;
    for (var i = 0; i < on[k]!; i++) {
      pages.add(PlannerPage(k, year: year, index: i));
    }
  }
  for (final c in custom) {
    for (var i = 0; i < c.count; i++) {
      pages.add(PlannerPage(SectionKind.custom, year: year, index: i, title: c.title, layout: c.layout));
    }
  }
  if (on.containsKey(SectionKind.namePage)) pages.add(PlannerPage(SectionKind.namePage, year: year));
  return pages;
}

/// Texto para mandarle a la clienta por WhatsApp.
String questionnaire() {
  final b = StringBuffer();
  b.writeln('✨ Agenda personalizada — Agustinita Papelería ✨');
  b.writeln('Para armar tu agenda necesito estos datos:');
  b.writeln('1) Nombre que va en la agenda:');
  b.writeln('2) Frase o texto que quieras incluir (opcional):');
  b.writeln('3) ¿Para qué la usarás? (trabajo, estudio, personal, regalo) y tu profesión:');
  b.writeln('4) Estilo: kawaii / pastel / floral / gótico suave / anime / minimal / elegante');
  b.writeln('5) Colores preferidos:');
  b.writeln('6) Tema o detalles que te gusten (gatos, flores, autos, estetoscopio…):');
  b.writeln('7) ¿Quieres tu caricatura en la portada y separadores? Si es así, mándame una foto de frente.');
  b.writeln('8) Año de la agenda y mes de inicio:');
  b.writeln('9) Secciones que quieres (marca las que sirvan):');
  for (final s in sectionCatalog.where((s) => !s.kind.name.startsWith('kid') && s.kind != SectionKind.namePage)) {
    b.writeln('   ☐ ${s.label} — ${s.hint}');
  }
  b.writeln('10) ¿Algo más que no esté en la lista?');
  return b.toString();
}
