/// Medidas reales de los productos de Agustinita Papelería (en mm),
/// extraídas de los PDF de producción de Cesar.
///
/// Todo lo que es papel se dibuja con código a estas medidas; la IA solo
/// aporta el arte (marco/personaje/portada).

const double mm = 72 / 25.4; // 1 mm en puntos PDF

/// Hoja carta.
const double letterW = 215.9;
const double letterH = 279.4;

/// Agenda anillada (anillado 15 mm, impresión doble cara).
/// Hoja carta horizontal cortada a la mitad: 2 páginas por cara.
class AgendaSpec {
  static const double sheetW = letterH; // 279.4 (horizontal)
  static const double sheetH = letterW; // 215.9
  static const double halfW = sheetW / 2; // 139.7 cada página
  static const double ringMargin = 15.0; // franja para los anillos
  static const double frameW = 120.3;
  static const double frameH = 185.9;
  static const double frameTop = 15.0;
  static const double frameRadius = 4.0;
  static const double innerPad = 6.0; // del marco al contenido
  static const int sheets = 24; // 24 hojas → 48 páginas
  static const int pages = sheets * 2;

  /// Portada: va sola en su hoja (carta vertical), del tamaño de una página.
  static const double coverW = halfW;
  static const double coverH = sheetH;
}

/// Post-its: tamaño de cada bloque y cómo se arman en una hoja carta.
class PostitSpec {
  final String id;
  final String label;
  final double w; // mm
  final double h; // mm
  final int perSheet;
  final String aiWidth; // ancho/alto que se le pide a la IA (px)
  final String aiHeight;

  const PostitSpec({
    required this.id,
    required this.label,
    required this.w,
    required this.h,
    required this.perSheet,
    required this.aiWidth,
    required this.aiHeight,
  });

  static const square = PostitSpec(
      id: 'cuadrado',
      label: 'Post-it cuadrado 10 × 10 cm',
      w: 100,
      h: 100,
      perSheet: 4,
      aiWidth: '1024',
      aiHeight: '1024');
  static const horizontal = PostitSpec(
      id: 'horizontal',
      label: 'Post-it horizontal 15 × 9 cm',
      w: 150,
      h: 90,
      perSheet: 2,
      aiWidth: '1344',
      aiHeight: '800');
  static const vertical = PostitSpec(
      id: 'vertical',
      label: 'Post-it vertical 7 × 15 cm',
      w: 70,
      h: 150,
      perSheet: 3,
      aiWidth: '720',
      aiHeight: '1536');

  static const all = [square, horizontal, vertical];
}

/// Tipos de página de la agenda (los que Cesar usa hoy).
enum PageKind {
  owner, // "Esta agenda es mía"
  notes, // Mis notas (rayado)
  handwriting, // Mi caligrafía (pauta punteada doble)
  calendar, // Calendario — 6 meses por página
  drawWrite, // Dibujo y escribo (recuadro + rayas)
  feelings, // Cómo me siento hoy
  therapyTasks, // Mis tareas del psicólogo (checklist)
  homework, // Desarrollo de mi tarea (rayado ancho)
  savings, // Mis primeros ahorros (tabla)
  achievements, // Mis logros (lista numerada)
  creative, // Escritura creativa
  namePage, // Página con el nombre y la frase
  custom, // Página extra definida por el usuario (título + pauta)
  blank,
}

/// Pautas disponibles para las páginas extra.
enum CustomLayout { ruled, handwriting, checklist, grid, dotted, table, box, numbered }

const customLayoutLabels = <CustomLayout, String>{
  CustomLayout.ruled: 'rayado',
  CustomLayout.handwriting: 'caligrafía',
  CustomLayout.checklist: 'checklist',
  CustomLayout.grid: 'cuadrícula',
  CustomLayout.dotted: 'punteado',
  CustomLayout.table: 'tabla',
  CustomLayout.box: 'recuadro',
  CustomLayout.numbered: 'lista numerada',
};

class PageDef {
  final PageKind kind;
  final int? year;
  final int? halfIndex; // 0 = ene-jun, 1 = jul-dic
  final String? title; // solo custom
  final CustomLayout? layout; // solo custom
  const PageDef(this.kind, {this.year, this.halfIndex, this.title, this.layout});
}

/// Página extra: "Horario de clases: cuadrícula x2"
class CustomPage {
  final String title;
  final CustomLayout layout;
  final int count;
  const CustomPage(this.title, this.layout, this.count);

  /// Parsea líneas tipo "Título: pauta xN". Pauta y xN son opcionales.
  static List<CustomPage> parse(String text) {
    final out = <CustomPage>[];
    for (final raw in text.split('\n')) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      var count = 1;
      final m = RegExp(r'\s*[x×]\s*(\d+)\s*$', caseSensitive: false).firstMatch(line);
      if (m != null) {
        count = int.parse(m.group(1)!).clamp(1, 50);
        line = line.substring(0, m.start).trim();
      }
      var title = line;
      var layout = CustomLayout.ruled;
      final idx = line.lastIndexOf(':');
      if (idx > 0) {
        final key = line.substring(idx + 1).trim().toLowerCase();
        final found = customLayoutLabels.entries
            .where((e) => key.startsWith(e.value.substring(0, 4)))
            .map((e) => e.key);
        if (found.isNotEmpty) {
          layout = found.first;
          title = line.substring(0, idx).trim();
        }
      }
      out.add(CustomPage(title, layout, count));
    }
    return out;
  }
}

const pageTitles = <PageKind, String>{
  PageKind.owner: 'Esta agenda es mía',
  PageKind.notes: 'Mis notas',
  PageKind.handwriting: 'Mi caligrafía',
  PageKind.calendar: 'Calendario',
  PageKind.drawWrite: 'Dibujo y escribo',
  PageKind.feelings: 'Cómo me siento hoy',
  PageKind.therapyTasks: 'Mis tareas del psicólogo',
  PageKind.homework: 'Desarrollo de mi tarea',
  PageKind.savings: 'Mis primeros ahorros',
  PageKind.achievements: 'Mis logros',
  PageKind.creative: 'Escritura creativa',
  PageKind.namePage: '',
  PageKind.blank: '',
};

/// Secuencia completa para [sheets] hojas (2 páginas por hoja):
/// bloque inicial (datos, notas, calendarios) + páginas extra del usuario +
/// relleno cíclico con el mix de la agenda de Agustina + cierre (nombre).
List<PageDef> buildAgendaPages({
  required int sheets,
  required int firstYear,
  List<CustomPage> custom = const [],
}) {
  final total = sheets * 2;
  final y = firstYear;
  final intro = <PageDef>[
    const PageDef(PageKind.owner),
    const PageDef(PageKind.notes),
    PageDef(PageKind.calendar, year: y, halfIndex: 0),
    PageDef(PageKind.calendar, year: y, halfIndex: 1),
    PageDef(PageKind.calendar, year: y + 1, halfIndex: 0),
    PageDef(PageKind.calendar, year: y + 1, halfIndex: 1),
  ];
  final extras = <PageDef>[
    for (final c in custom)
      for (var i = 0; i < c.count; i++)
        PageDef(PageKind.custom, title: c.title, layout: c.layout),
  ];
  const cycle = [
    PageKind.handwriting, PageKind.notes, PageKind.drawWrite, PageKind.handwriting,
    PageKind.therapyTasks, PageKind.homework, PageKind.feelings, PageKind.handwriting,
    PageKind.savings, PageKind.creative, PageKind.handwriting, PageKind.achievements,
    PageKind.notes, PageKind.handwriting,
  ];
  final outro = <PageDef>[const PageDef(PageKind.namePage), const PageDef(PageKind.creative)];

  final pages = <PageDef>[...intro, ...extras];
  var i = 0;
  while (pages.length < total - outro.length) {
    pages.add(PageDef(cycle[i % cycle.length]));
    i++;
  }
  pages.addAll(outro);
  while (pages.length > total) {
    pages.removeAt(pages.length - outro.length - 1);
  }
  while (pages.length < total) {
    pages.add(const PageDef(PageKind.blank));
  }
  return pages;
}

/// Secuencia por defecto (48 páginas), tomada de la agenda de Agustina.
List<PageDef> defaultAgendaPages(int firstYear) {
  final y = firstYear;
  return [
    const PageDef(PageKind.owner),
    const PageDef(PageKind.notes),
    const PageDef(PageKind.handwriting),
    PageDef(PageKind.calendar, year: y, halfIndex: 0),
    PageDef(PageKind.calendar, year: y, halfIndex: 1),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.drawWrite),
    PageDef(PageKind.calendar, year: y + 1, halfIndex: 0),
    PageDef(PageKind.calendar, year: y + 1, halfIndex: 1),
    const PageDef(PageKind.therapyTasks),
    const PageDef(PageKind.homework),
    PageDef(PageKind.calendar, year: y + 2, halfIndex: 0),
    PageDef(PageKind.calendar, year: y + 2, halfIndex: 1),
    const PageDef(PageKind.feelings),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.savings),
    const PageDef(PageKind.savings),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.notes),
    const PageDef(PageKind.therapyTasks),
    const PageDef(PageKind.homework),
    const PageDef(PageKind.creative),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.achievements),
    const PageDef(PageKind.notes),
    const PageDef(PageKind.drawWrite),
    const PageDef(PageKind.therapyTasks),
    const PageDef(PageKind.homework),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.feelings),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.achievements),
    const PageDef(PageKind.therapyTasks),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.notes),
    const PageDef(PageKind.homework),
    const PageDef(PageKind.feelings),
    const PageDef(PageKind.drawWrite),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.handwriting),
    const PageDef(PageKind.namePage),
    const PageDef(PageKind.blank),
    const PageDef(PageKind.creative),
  ];
}
