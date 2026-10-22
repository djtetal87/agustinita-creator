/// Feriados de Chile calculados para cualquier año.
///
/// Incluye los irrenunciables y los fijos por ley, Semana Santa (calculada),
/// y la regla de traslado al lunes (Ley 19.973) para San Pedro y San Pablo,
/// Encuentro de Dos Mundos y Día de las Iglesias Evangélicas.
/// Los feriados por elecciones y censos no se incluyen (varían cada año).
class Holiday {
  final DateTime date;
  final String name;
  const Holiday(this.date, this.name);
}

DateTime _easter(int y) {
  // Algoritmo de Meeus/Jones/Butcher (calendario gregoriano)
  final a = y % 19, b = y ~/ 100, c = y % 100, d = b ~/ 4, e = b % 4;
  final f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3, h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31, day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(y, month, day);
}

/// Ley 19.973: 29 de junio y 12 de octubre, si caen martes se trasladan al
/// lunes anterior; si caen miércoles, al lunes siguiente.
DateTime _toMonday(DateTime d) {
  switch (d.weekday) {
    case DateTime.tuesday:
      return d.subtract(const Duration(days: 1));
    case DateTime.wednesday:
      return d.add(const Duration(days: 5));
    default:
      return d;
  }
}

/// Día de las Iglesias Evangélicas (31 oct): si cae martes → viernes anterior;
/// miércoles → viernes siguiente.
DateTime _evangelicas(int y) {
  final d = DateTime(y, 10, 31);
  if (d.weekday == DateTime.tuesday) return d.subtract(const Duration(days: 4));
  if (d.weekday == DateTime.wednesday) return d.add(const Duration(days: 2));
  return d;
}

List<Holiday> chileHolidays(int y) {
  final easter = _easter(y);
  final list = <Holiday>[
    Holiday(DateTime(y, 1, 1), 'Año Nuevo'),
    Holiday(easter.subtract(const Duration(days: 2)), 'Viernes Santo'),
    Holiday(easter.subtract(const Duration(days: 1)), 'Sábado Santo'),
    Holiday(DateTime(y, 5, 1), 'Día del Trabajo'),
    Holiday(DateTime(y, 5, 21), 'Glorias Navales'),
    Holiday(DateTime(y, 6, y % 4 == 0 ? 20 : 21), 'Pueblos Indígenas'), // solsticio de invierno
    Holiday(_toMonday(DateTime(y, 6, 29)), 'San Pedro y San Pablo'),
    Holiday(DateTime(y, 7, 16), 'Virgen del Carmen'),
    Holiday(DateTime(y, 8, 15), 'Asunción de la Virgen'),
    Holiday(DateTime(y, 9, 18), 'Independencia Nacional'),
    Holiday(DateTime(y, 9, 19), 'Glorias del Ejército'),
    Holiday(_toMonday(DateTime(y, 10, 12)), 'Encuentro de Dos Mundos'),
    Holiday(_evangelicas(y), 'Iglesias Evangélicas'),
    Holiday(DateTime(y, 11, 1), 'Todos los Santos'),
    Holiday(DateTime(y, 12, 8), 'Inmaculada Concepción'),
    Holiday(DateTime(y, 12, 25), 'Navidad'),
  ];
  // 17 sep / 20 sep feriados "sándwich" cuando corresponde
  final d18 = DateTime(y, 9, 18);
  if (d18.weekday == DateTime.tuesday) list.add(Holiday(DateTime(y, 9, 17), 'Feriado adicional'));
  if (d18.weekday == DateTime.thursday) list.add(Holiday(DateTime(y, 9, 20), 'Feriado adicional'));
  list.sort((a, b) => a.date.compareTo(b.date));
  return list;
}

bool isHoliday(List<Holiday> hs, DateTime d) =>
    hs.any((h) => h.date.year == d.year && h.date.month == d.month && h.date.day == d.day);
