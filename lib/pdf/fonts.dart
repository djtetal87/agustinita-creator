import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Fuentes embebidas en los PDF (por ahora Poppins; se cambian por las de
/// Cesar poniendo los .ttf en assets/fonts y ajustando pubspec).
class PdfFonts {
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font bold;
  final pw.Font title; // cursiva no tradicional (títulos de página)
  final pw.Font display; // gruesa redondeada (nombre en portada)
  const PdfFonts(this.regular, this.medium, this.bold, this.title, this.display);

  static PdfFonts? _cache;

  static Future<PdfFonts> load() async {
    if (_cache != null) return _cache!;
    final r = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    final m = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Medium.ttf'));
    final b = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    final t = pw.Font.ttf(await rootBundle.load('assets/fonts/Pacifico-Regular.ttf'));
    final d = pw.Font.ttf(await rootBundle.load('assets/fonts/LilitaOne-Regular.ttf'));
    return _cache = PdfFonts(r, m, b, t, d);
  }
}
