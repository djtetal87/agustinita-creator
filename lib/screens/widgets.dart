import 'dart:typed_data';

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

void toast(BuildContext context, String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
