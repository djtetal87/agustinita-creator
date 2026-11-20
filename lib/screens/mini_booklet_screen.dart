import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../app_settings.dart';
import '../export.dart';
import '../pdf/mini_booklet_builder.dart';
import 'widgets.dart';

class MiniBookletScreen extends StatefulWidget {
  final AppSettings settings;
  const MiniBookletScreen({super.key, required this.settings});

  @override
  State<MiniBookletScreen> createState() => _MiniBookletScreenState();
}

class _MiniBookletScreenState extends State<MiniBookletScreen> {
  static const _hint =
      "Imprime a doble cara, volteo por borde largo, tamaño Carta, escala 100 % (sin 'ajustar a página'). "
      'Corta por la mitad horizontal, dobla cada tira e inserta la de abajo dentro de la de arriba.';

  final List<Uint8List?> _imgs = List.filled(8, null);
  final List<bool> _rot = List.filled(8, false);
  bool _fill = false;
  double _margin = 0;
  bool _guides = true;
  int _copies = 1;

  bool _busyExport = false;
  bool _busyPreview = false;
  List<Uint8List>? _preview;
  Timer? _debounce;
  int _previewGen = 0;

  AppSettings get s => widget.settings;
  bool get _complete => _imgs.every((e) => e != null);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  MiniBookletJob _job({bool preview = false}) => MiniBookletJob(
        images: List.of(_imgs),
        rotate90: List.of(_rot),
        fill: _fill,
        marginMm: _margin,
        guides: _guides,
        backOffsetX: s.backOffsetX,
        backOffsetY: s.backOffsetY,
        copies: preview ? 1 : _copies,
      );

  /// pdf solo entiende JPEG y PNG: cualquier otro formato se pasa a PNG.
  Future<Uint8List> _normalize(Uint8List b) async {
    final jpg = b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;
    final png = b.length > 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
    if (jpg || png) return b;
    final codec = await ui.instantiateImageCodec(b);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw 'No se pudo leer la imagen';
    return data.buffer.asUint8List();
  }

  void _changed() {
    setState(() {});
    _debounce?.cancel();
    if (_imgs.every((e) => e == null)) {
      setState(() => _preview = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), _refreshPreview);
  }

  Future<void> _refreshPreview() async {
    final gen = ++_previewGen;
    setState(() => _busyPreview = true);
    try {
      final pdf = await MiniBookletBuilder.build(_job(preview: true));
      final out = <Uint8List>[];
      await for (final page in Printing.raster(pdf, pages: [0, 1], dpi: 70)) {
        out.add(await page.toPng());
      }
      if (!mounted || gen != _previewGen) return;
      setState(() => _preview = out);
    } catch (e) {
      if (mounted && gen == _previewGen) toast(context, 'Error en la vista previa: $e');
    } finally {
      if (mounted && gen == _previewGen) setState(() => _busyPreview = false);
    }
  }

  Future<void> _pick(int i) async {
    try {
      final b = await pickImageFull();
      if (b == null) return;
      _imgs[i] = await _normalize(b);
      _rot[i] = false;
      _changed();
    } catch (e) {
      if (mounted) toast(context, 'No se pudo cargar la imagen: $e');
    }
  }

  Future<void> _pickMany() async {
    try {
      final list = await pickImages();
      if (list.isEmpty) return;
      var n = 0;
      for (final raw in list) {
        final slot = _imgs.indexWhere((e) => e == null);
        if (slot < 0) break;
        _imgs[slot] = await _normalize(raw);
        _rot[slot] = false;
        n++;
      }
      if (n < list.length && mounted) toast(context, 'Solo había espacio para $n imágenes.');
      _changed();
    } catch (e) {
      if (mounted) toast(context, 'No se pudieron cargar las imágenes: $e');
    }
  }

  void _clear(int i) {
    _imgs[i] = null;
    _rot[i] = false;
    _changed();
  }

  void _setOffset({double? x, double? y}) {
    if (x != null) s.backOffsetX = x.clamp(-5.0, 5.0).toDouble();
    if (y != null) s.backOffsetY = y.clamp(-5.0, 5.0).toDouble();
    s.save();
    _changed();
  }

  Future<void> _export() async {
    setState(() => _busyExport = true);
    try {
      final bytes = await MiniBookletBuilder.build(_job());
      final path = await exportPdf(bytes, 'MiniAgenda_Navidad.pdf');
      if (mounted && path != null) toast(context, 'PDF exportado.');
    } catch (e) {
      if (mounted) toast(context, 'Error al exportar: $e');
    } finally {
      if (mounted) setState(() => _busyExport = false);
    }
  }

  Future<void> _exportTest() async {
    setState(() => _busyExport = true);
    try {
      final bytes = await MiniBookletBuilder.buildAlignmentTest(backOffsetX: s.backOffsetX, backOffsetY: s.backOffsetY);
      final path = await exportPdf(bytes, 'MiniAgenda_prueba_alineacion.pdf');
      if (mounted && path != null) toast(context, 'Hoja de prueba exportada.');
    } catch (e) {
      if (mounted) toast(context, 'Error al exportar: $e');
    } finally {
      if (mounted) setState(() => _busyExport = false);
    }
  }

  // ---------- UI ----------

  Widget _slot(int i) {
    final b = _imgs[i];
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Expanded(
        child: AspectRatio(
          aspectRatio: 107.95 / 139.7,
          child: GestureDetector(
            onTap: () => _pick(i),
            onLongPress: b == null ? null : () => _clear(i),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                border: Border.all(color: b == null ? cs.outline : cs.primary, width: b == null ? 1 : 2),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: b == null
                  ? Center(child: Icon(Icons.add_photo_alternate_outlined, color: cs.outline))
                  : Stack(fit: StackFit.expand, children: [
                      Padding(
                        padding: const EdgeInsets.all(1),
                        child: RotatedBox(
                          quarterTurns: _rot[i] ? 3 : 0,
                          child: Image.memory(b, fit: BoxFit.contain, gaplessPlayback: true, cacheWidth: 300),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: _miniBtn(Icons.close, () => _clear(i)),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        child: _miniBtn(Icons.rotate_90_degrees_cw_outlined, () {
                          _rot[i] = !_rot[i];
                          _changed();
                        }, active: _rot[i]),
                      ),
                    ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 2),
      Text(MiniBookletBuilder.labels[i], style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
    ]);
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap, {bool active = false}) => InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? Theme.of(context).colorScheme.primary : Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      );

  Widget _stepper(String label, double value, ValueChanged<double> onChanged, {double min = -5, double max = 5, String unit = ' mm'}) {
    return Row(children: [
      Expanded(child: Text(label)),
      IconButton.outlined(
        onPressed: value <= min ? null : () => onChanged(value - 0.5),
        icon: const Icon(Icons.remove),
        tooltip: 'Menos',
      ),
      SizedBox(
        width: 84,
        child: Text('${value > 0 ? '+' : ''}${value.toStringAsFixed(1).replaceAll('.', ',')}$unit',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
      ),
      IconButton.outlined(
        onPressed: value >= max ? null : () => onChanged(value + 0.5),
        icon: const Icon(Icons.add),
        tooltip: 'Más',
      ),
    ]);
  }

  Widget _readingStrip() {
    // Orden de lectura del librito: p1 Tapa, p2..p7 Act1..6, p8 Contratapa.
    const order = [0, 2, 3, 4, 5, 6, 7, 1];
    return SizedBox(
      height: 92,
      child: Row(children: [
        for (var p = 0; p < 8; p++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 107.95 / 139.7,
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
                      child: _imgs[order[p]] == null
                          ? null
                          : RotatedBox(
                              quarterTurns: _rot[order[p]] ? 3 : 0,
                              child: Image.memory(_imgs[order[p]]!, fit: BoxFit.contain, cacheWidth: 120, gaplessPlayback: true)),
                    ),
                  ),
                ),
                Text('p${p + 1}', style: Theme.of(context).textTheme.labelSmall),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _previewPane() {
    final pv = _preview;
    Widget side(String title, int i) => Column(children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.black26), color: Colors.white),
            child: Image.memory(pv![i], fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('Vista previa', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        if (_busyPreview) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 8),
      if (pv == null || pv.length < 2)
        Text('Carga imágenes para ver cómo queda la hoja (frente y reverso).', style: Theme.of(context).textTheme.bodySmall)
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: side('Frente', 0)),
          const SizedBox(width: 12),
          Expanded(child: side('Reverso', 1)),
        ]),
      const SizedBox(height: 16),
      Text('Orden de lectura', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      _readingStrip(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    final filled = _imgs.where((e) => e != null).length;

    final form = <Widget>[
      Text('Mini agenda navideña', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('Librito de 8 páginas en una hoja Carta doble cara (107,95 × 139,7 mm por página). Sube las 8 imágenes en orden de lectura.',
          style: Theme.of(context).textTheme.bodySmall),
      const SectionTitle('Imágenes'),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 520 ? 4 : 4;
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < 8; i++) SizedBox(width: w, height: w * 139.7 / 107.95 + 20, child: _slot(i)),
        ]);
      }),
      const SizedBox(height: 4),
      Text('Toca para elegir o reemplazar; mantén presionado o usa la x para quitar; el botón de giro rota la imagen 90°.',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _pickMany,
        icon: const Icon(Icons.collections_outlined),
        label: Text('Cargar varias ($filled/8)'),
      ),
      const SectionTitle('Encaje'),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Completa')),
          ButtonSegment(value: true, label: Text('Rellenar')),
        ],
        selected: {_fill},
        onSelectionChanged: (v) {
          _fill = v.first;
          _changed();
        },
      ),
      const SizedBox(height: 4),
      Text(_fill ? 'Rellenar: cubre toda la página y recorta lo que sobre.' : 'Completa: la imagen entera, centrada, sin recortar.',
          style: Theme.of(context).textTheme.bodySmall),
      const SectionTitle('Margen interior'),
      SegmentedButton<double>(
        segments: const [
          ButtonSegment(value: 0, label: Text('0 mm')),
          ButtonSegment(value: 2, label: Text('2 mm')),
          ButtonSegment(value: 3, label: Text('3 mm')),
          ButtonSegment(value: 5, label: Text('5 mm')),
        ],
        selected: {_margin},
        onSelectionChanged: _fill
            ? null
            : (v) {
                _margin = v.first;
                _changed();
              },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Guías de corte y doblez'),
        subtitle: const Text('Marcas cortas en los bordes del frente'),
        value: _guides,
        onChanged: (v) {
          _guides = v;
          _changed();
        },
      ),
      const SectionTitle('Ajuste del reverso'),
      _stepper('Horizontal (X)', s.backOffsetX, (v) => _setOffset(x: v)),
      _stepper('Vertical (Y)', s.backOffsetY, (v) => _setOffset(y: v)),
      Text('Desplaza todo el reverso. + mueve a la derecha / hacia abajo. Se guarda para la próxima vez.',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busyExport ? null : _exportTest,
        icon: const Icon(Icons.grid_on_outlined),
        label: const Text('Hoja de prueba de alineación'),
      ),
      const SectionTitle('Copias'),
      _stepperInt(),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: (_busyExport || !_complete) ? null : _export,
        icon: _busyExport
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.picture_as_pdf),
        label: const Text('Exportar PDF (doble cara)'),
      ),
      const SizedBox(height: 8),
      Text(_complete ? _hint : 'Faltan ${8 - filled} imágenes. $_hint', style: Theme.of(context).textTheme.bodySmall),
    ];

    if (!wide) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        ...form,
        const SizedBox(height: 24),
        _previewPane(),
        const SizedBox(height: 24),
      ]);
    }
    return Row(children: [
      Expanded(flex: 5, child: ListView(padding: const EdgeInsets.all(20), children: form)),
      const VerticalDivider(width: 1),
      Expanded(flex: 5, child: ListView(padding: const EdgeInsets.all(20), children: [_previewPane()])),
    ]);
  }

  Widget _stepperInt() => Row(children: [
        const Expanded(child: Text('Número de librillos')),
        IconButton.outlined(
          onPressed: _copies <= 1 ? null : () => setState(() => _copies--),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(width: 56, child: Text('$_copies', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall)),
        IconButton.outlined(
          onPressed: _copies >= 50 ? null : () => setState(() => _copies++),
          icon: const Icon(Icons.add),
        ),
      ]);
}
