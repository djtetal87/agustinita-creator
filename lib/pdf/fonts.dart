import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Fuentes embebidas en los PDF (por ahora Poppins; se cambian por las de
/// Cesar poniendo los .ttf en assets/fonts y ajustando pubspec).
class PdfFonts {
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font bold;
  const PdfFonts(this.regular, this.medium, this.bold);

  static PdfFonts? _cache;

  static Future<PdfFonts> load() async {
    if (_cache != null) return _cache!;
    final r = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    final m = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Medium.ttf'));
    final b = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    return _cache = PdfFonts(r, m, b);
  }
}
