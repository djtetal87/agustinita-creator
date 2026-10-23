import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Fuentes cursivas disponibles para los títulos (todas OFL, uso comercial libre).
const scriptFonts = <String, String>{
  'stylescript': 'Style Script',
  'marck': 'Marck Script',
  'parisienne': 'Parisienne',
  'sacramento': 'Sacramento',
  'allura': 'Allura',
};
const _scriptFiles = <String, String>{
  'stylescript': 'StyleScript-Regular.ttf',
  'marck': 'MarckScript-Regular.ttf',
  'parisienne': 'Parisienne-Regular.ttf',
  'sacramento': 'Sacramento-Regular.ttf',
  'allura': 'Allura-Regular.ttf',
};

/// Cómo se componen los títulos.
enum TitleStyle { dual, script, plain }

/// Fuentes embebidas en los PDF.
class PdfFonts {
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font bold;
  final pw.Font title; // cursiva elegida (títulos, frase)
  final pw.Font display; // gruesa redondeada (nombre en portada)
  final TitleStyle titleStyle;
  /// Factor para igualar la altura visual de la cursiva con Poppins Bold.
  final double scriptScale;
  const PdfFonts(this.regular, this.medium, this.bold, this.title, this.display,
      {this.titleStyle = TitleStyle.dual, this.scriptScale = 1.35});

  static final Map<String, pw.Font> _cache = {};

  static Future<pw.Font> _f(String file) async =>
      _cache[file] ??= pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));

  static Future<PdfFonts> load({String script = 'stylescript', TitleStyle titleStyle = TitleStyle.dual}) async {
    final r = await _f('Poppins-Regular.ttf');
    final m = await _f('Poppins-Medium.ttf');
    final b = await _f('Poppins-Bold.ttf');
    final t = await _f(_scriptFiles[script] ?? _scriptFiles['stylescript']!);
    final d = await _f('LilitaOne-Regular.ttf');
    // las cursivas finas (Allura, Parisienne, Sacramento) necesitan más tamaño
    final scale = {'allura': 1.55, 'parisienne': 1.5, 'sacramento': 1.6, 'marck': 1.4, 'stylescript': 1.35}[script] ?? 1.4;
    return PdfFonts(r, m, b, t, d, titleStyle: titleStyle, scriptScale: scale);
  }
}
