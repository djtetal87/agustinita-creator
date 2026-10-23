import 'package:pdf/pdf.dart';

/// Paleta de cada estilo: colores del marco, títulos y pautas del papel,
/// más la descripción que se le pasa a la IA para el arte.
class StyleSpec {
  final String id;
  final String label;
  final PdfColor frame; // borde del marco de página
  final PdfColor titleBg; // píldora del título
  final PdfColor titleFg; // texto del título
  final PdfColor rule; // rayas / puntos
  final PdfColor accent; // acentos (números, checks)
  final String aiPrompt; // estética para el generador

  const StyleSpec({
    required this.id,
    required this.label,
    required this.frame,
    required this.titleBg,
    required this.titleFg,
    required this.rule,
    required this.accent,
    required this.aiPrompt,
  });

  static const kawaii = StyleSpec(
    id: 'kawaii',
    label: 'Kawaii (tipo Sanrio)',
    frame: PdfColor.fromInt(0xFFF4B6D4),
    titleBg: PdfColor.fromInt(0xFFF9DCEA),
    titleFg: PdfColor.fromInt(0xFF7B4A9E),
    rule: PdfColor.fromInt(0xFF8E7CC3),
    accent: PdfColor.fromInt(0xFFE98BB6),
    aiPrompt:
        'ilustración kawaii estilo Sanrio, línea limpia y gruesa, sombreado plano, colores pastel (rosa chicle, lila suave, crema, durazno), ojos grandes brillantes, corazones y estrellas pequeñas, muy tierno',
  );
  static const pastel = StyleSpec(
    id: 'pastel',
    label: 'Pastel suave',
    frame: PdfColor.fromInt(0xFFBFD8F2),
    titleBg: PdfColor.fromInt(0xFFE3EEFA),
    titleFg: PdfColor.fromInt(0xFF4A6C9E),
    rule: PdfColor.fromInt(0xFF8EA7C9),
    accent: PdfColor.fromInt(0xFF9EC3E8),
    aiPrompt:
        'ilustración suave en acuarela digital, paleta pastel (rosa, beige, menta suave, durazno, lavanda), bordes difuminados, nubes, flores pequeñas, sensación calmada y dulce',
  );
  static const floral = StyleSpec(
    id: 'floral',
    label: 'Floral',
    frame: PdfColor.fromInt(0xFFB9D7B4),
    titleBg: PdfColor.fromInt(0xFFE4F1E1),
    titleFg: PdfColor.fromInt(0xFF4E7A4A),
    rule: PdfColor.fromInt(0xFF86A883),
    accent: PdfColor.fromInt(0xFFE6A6B8),
    aiPrompt:
        'ilustración botánica delicada, flores silvestres, hojas de eucalipto, ramas finas, acuarela y tinta, paleta verde salvia, rosa viejo y crema, estilo papelería elegante',
  );
  static const gothic = StyleSpec(
    id: 'gotico',
    label: 'Gótico suave',
    frame: PdfColor.fromInt(0xFF8E7CC3),
    titleBg: PdfColor.fromInt(0xFFE6E0F3),
    titleFg: PdfColor.fromInt(0xFF3A2E5C),
    rule: PdfColor.fromInt(0xFF7D6FA8),
    accent: PdfColor.fromInt(0xFFB58BD6),
    aiPrompt:
        'ilustración kawaii gótica (pastel goth), negro con lila y rosa, murciélagos tiernos, lunas, calaveras adorables, encaje, estrellas, línea limpia, sombreado plano',
  );
  static const anime = StyleSpec(
    id: 'anime',
    label: 'Anime',
    frame: PdfColor.fromInt(0xFFF2A6A0),
    titleBg: PdfColor.fromInt(0xFFFBE1DF),
    titleFg: PdfColor.fromInt(0xFF8C3B3B),
    rule: PdfColor.fromInt(0xFFB07C7C),
    accent: PdfColor.fromInt(0xFFF08C8C),
    aiPrompt:
        'ilustración estilo anime chibi, colores vivos pero suaves, destellos, pétalos de cerezo, línea limpia, ojos expresivos, estilo sticker',
  );
  static const minimal = StyleSpec(
    id: 'minimal',
    label: 'Minimal',
    frame: PdfColor.fromInt(0xFFCBCBCB),
    titleBg: PdfColor.fromInt(0xFFF0F0F0),
    titleFg: PdfColor.fromInt(0xFF333333),
    rule: PdfColor.fromInt(0xFFB0B0B0),
    accent: PdfColor.fromInt(0xFF888888),
    aiPrompt:
        'ilustración minimalista de una sola línea, mucho espacio en blanco, un solo color de acento, formas geométricas simples, estilo escandinavo',
  );

  /// "Similar a la portada de referencia": colores neutros-rosados para el
  /// papel; la IA copia el estilo de la portada subida.
  static const reference = StyleSpec(
    id: 'referencia',
    label: 'Similar a la portada de referencia',
    frame: PdfColor.fromInt(0xFFE2C4D6),
    titleBg: PdfColor.fromInt(0xFFF6E7EF),
    titleFg: PdfColor.fromInt(0xFF6B4A7E),
    rule: PdfColor.fromInt(0xFF9A8AB5),
    accent: PdfColor.fromInt(0xFFE49BBE),
    aiPrompt:
        'el MISMO estilo de ilustración, paleta de colores, tipo de línea y nivel de detalle de la imagen de referencia',
  );

  static const all = [kawaii, pastel, floral, gothic, anime, minimal, reference];

  static StyleSpec byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => kawaii);

  /// Colores preestablecidos para el texto del papel.
  static const inkPresets = <String, int>{
    'Morado': 0xFF6B4A7E,
    'Rosa': 0xFFC2527F,
    'Verde salvia': 0xFF5F7F5B,
    'Terracota': 0xFFB5654A,
    'Azul marino': 0xFF2F4A6D,
    'Café': 0xFF6E4B3A,
    'Gris oscuro': 0xFF444444,
    'Negro': 0xFF1E1E1E,
    'Dorado': 0xFFB08D3C,
  };

  /// Copia de este estilo con la paleta derivada de un solo color base:
  /// títulos/números en el color, líneas al 45 %, píldoras al 15 %,
  /// borde del marco al 35 %. [ruleColor]/[pillColor] permiten ajuste fino.
  StyleSpec withInk(PdfColor ink, {PdfColor? ruleColor, PdfColor? pillColor}) {
    PdfColor mix(PdfColor c, double t) => PdfColor(
          c.red + (1 - c.red) * (1 - t),
          c.green + (1 - c.green) * (1 - t),
          c.blue + (1 - c.blue) * (1 - t),
        );
    return StyleSpec(
      id: id,
      label: label,
      frame: mix(ink, 0.35),
      titleBg: pillColor ?? mix(ink, 0.15),
      titleFg: ink,
      rule: ruleColor ?? mix(ink, 0.45),
      accent: mix(ink, 0.85),
      aiPrompt: aiPrompt,
    );
  }

  static PdfColor? parseHex(String s) {
    var h = s.trim().replaceAll('#', '');
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : PdfColor.fromInt(0xFF000000 | v);
  }
}
