import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme_spec.dart';

class StyleChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const StyleChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: StyleSpec.all
          .map((s) => ChoiceChip(
                label: Text(s.label),
                selected: selected == s.id,
                onSelected: (_) => onChanged(s.id),
              ))
          .toList(),
    );
  }
}

class Field extends StatelessWidget {
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final IconData? icon;
  final TextEditingController? controller;
  const Field(this.label, this.hint, this.onChanged,
      {super.key, this.maxLines = 1, this.icon, this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

/// Vista previa de una imagen generada, con botón de regenerar.
class ArtPreview extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final bool busy;
  final VoidCallback? onRegenerate;
  final double height;
  const ArtPreview({
    super.key,
    required this.label,
    required this.bytes,
    this.busy = false,
    this.onRegenerate,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          if (onRegenerate != null)
            TextButton.icon(
              onPressed: busy ? null : onRegenerate,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Regenerar'),
            ),
        ]),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: busy
              ? const CircularProgressIndicator()
              : bytes == null
                  ? Icon(Icons.image_outlined, color: cs.outline, size: 40)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(bytes!, fit: BoxFit.contain),
                    ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// "¿Para quién es?" — Mujer / Hombre / Niña / Niño / Neutro.
class AudienceChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const AudienceChips({super.key, required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in StyleSpec.audiences.entries)
          ChoiceChip(label: Text(e.value), selected: selected == e.key, onSelected: (_) => onChanged(e.key)),
      ]);
}

/// Selector de color del texto del papel: muestras + hex + "tomar de la portada".
class InkPicker extends StatelessWidget {
  final String hex;
  final ValueChanged<String> onChanged;
  final List<Color> fromCover; // colores dominantes de la portada (puede estar vacío)
  const InkPicker({super.key, required this.hex, required this.onChanged, this.fromCover = const []});

  @override
  Widget build(BuildContext context) {
    Color? cur;
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 6) cur = Color(0xFF000000 | int.parse(h, radix: 16));
    } catch (_) {}
    Widget swatch(Color c, String label) {
      final hx = '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
      final sel = cur != null && cur.value == c.value;
      return Tooltip(
        message: label,
        child: GestureDetector(
          onTap: () => onChanged(hx),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: sel ? Theme.of(context).colorScheme.primary : Colors.white, width: sel ? 3 : 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
            ),
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Color del texto (títulos, números, líneas)', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        swatch(const Color(0xFF6B4A7E), 'Morado'),
        swatch(const Color(0xFFC2527F), 'Rosa'),
        swatch(const Color(0xFF5F7F5B), 'Verde salvia'),
        swatch(const Color(0xFFB5654A), 'Terracota'),
        swatch(const Color(0xFF2F4A6D), 'Azul marino'),
        swatch(const Color(0xFF6E4B3A), 'Café'),
        swatch(const Color(0xFFB08D3C), 'Dorado'),
        swatch(const Color(0xFF444444), 'Gris oscuro'),
        swatch(const Color(0xFF1E1E1E), 'Negro'),
      ]),
      if (fromCover.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('De la portada:', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [for (final c in fromCover) swatch(c, 'Tomado de la portada')]),
      ],
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(
          width: 140,
          child: TextFormField(
            initialValue: hex,
            decoration: const InputDecoration(labelText: 'Hex', isDense: true, border: OutlineInputBorder()),
            onChanged: (v) { if (v.replaceAll('#', '').length == 6) onChanged(v.startsWith('#') ? v : '#$v'); },
          ),
        ),
        const SizedBox(width: 12),
        if (cur != null) Container(width: 28, height: 28, decoration: BoxDecoration(color: cur, borderRadius: BorderRadius.circular(6))),
        const SizedBox(width: 12),
        TextButton(onPressed: () => onChanged(''), child: const Text('Usar paleta del estilo')),
      ]),
    ]);
  }
}

/// Colores dominantes de una imagen (muestreo rápido, agrupado en cubos).
List<Color> dominantColors(Uint8List png, {int count = 4}) {
  try {
    final img = _decode(png);
    if (img == null) return const [];
    final buckets = <int, List<int>>{}; // key → [r,g,b,n]
    final w = img.width, h = img.height;
    final step = (w * h / 4000).ceil().clamp(1, 1 << 20);
    final bytes = img.bytes;
    for (var i = 0; i < w * h; i += step) {
      final r = bytes[i * 4], g = bytes[i * 4 + 1], b = bytes[i * 4 + 2];
      // descartar casi blancos y casi negros
      final mx = [r, g, b].reduce((a, b) => a > b ? a : b);
      final mn = [r, g, b].reduce((a, b) => a < b ? a : b);
      if (mx > 235 && mn > 215) continue;
      if (mx < 35) continue;
      if (mx - mn < 25) continue; // grises
      final key = (r >> 5 << 6) | (g >> 5 << 3) | (b >> 5);
      final e = buckets.putIfAbsent(key, () => [0, 0, 0, 0]);
      e[0] += r; e[1] += g; e[2] += b; e[3]++;
    }
    final sorted = buckets.values.toList()..sort((a, b) => b[3].compareTo(a[3]));
    return [
      for (final e in sorted.take(count))
        // oscurecer un poco para que sirva como tinta
        Color.fromARGB(255, (e[0] / e[3] * 0.75).round(), (e[1] / e[3] * 0.75).round(), (e[2] / e[3] * 0.75).round()),
    ];
  } catch (_) {
    return const [];
  }
}

class _Rgba {
  final int width, height;
  final Uint8List bytes;
  _Rgba(this.width, this.height, this.bytes);
}

_Rgba? _decode(Uint8List png) {
  // decodificación síncrona vía dart:ui no está disponible aquí; se hace en la pantalla
  return _decoded[png.hashCode];
}

final Map<int, _Rgba> _decoded = {};

/// Decodifica (async) y guarda para que dominantColors la pueda usar.
Future<void> prepareImageForColors(Uint8List png) async {
  if (_decoded.containsKey(png.hashCode)) return;
  final codec = await ui.instantiateImageCodec(png, targetWidth: 120);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return;
  _decoded[png.hashCode] = _Rgba(frame.image.width, frame.image.height, data.buffer.asUint8List());
}

void toast(BuildContext context, String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
