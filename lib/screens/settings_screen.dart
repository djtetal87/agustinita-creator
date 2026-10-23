import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../pdf/fonts.dart' show scriptFonts;

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSaved;
  const SettingsScreen({super.key, required this.settings, required this.onSaved});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _key = TextEditingController(text: widget.settings.falKey);
  late String _model = widget.settings.falModel;
  late String _script = widget.settings.titleScript;
  late String _tstyle = widget.settings.titleStyle;
  bool _show = false;

  Future<void> _save() async {
    widget.settings
      ..falKey = _key.text
      ..falModel = _model
      ..titleScript = _script
      ..titleStyle = _tstyle;
    await widget.settings.save();
    widget.onSaved();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Ajustes', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          controller: _key,
          obscureText: !_show,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'API key de fal.ai',
            hintText: 'la misma de PhotoTetal',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _model,
          decoration: const InputDecoration(labelText: 'Modelo Flux (texto → imagen)', border: OutlineInputBorder()),
          items: [for (final e in AppSettings.falModels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _model = v ?? _model),
        ),
        const SizedBox(height: 8),
        Text('Las conversiones de foto a personaje y las portadas con personaje usan Flux Kontext (~4 ¢ cada una).',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        Text('Títulos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _tstyle,
          decoration: const InputDecoration(labelText: 'Estilo de título', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'dual', child: Text('Doble fuente (negrita + cursiva)')),
            DropdownMenuItem(value: 'script', child: Text('Todo en cursiva')),
            DropdownMenuItem(value: 'plain', child: Text('Todo en negrita')),
          ],
          onChanged: (v) => setState(() => _tstyle = v ?? _tstyle),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _script,
          decoration: const InputDecoration(labelText: 'Fuente cursiva', border: OutlineInputBorder()),
          items: [for (final e in scriptFonts.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _script = v ?? _script),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
        const SizedBox(height: 32),
        Text('Medidas fijas', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        const Text('• Agenda: A5 (hoja A4 horizontal, 2 páginas de 148,5 × 210 mm) o media carta; anillos 15 mm.\n'
            '• Post-it cuadrado 100 × 100 mm (4 por carta) · horizontal 150 × 90 mm (2) · vertical 70 × 150 mm (3).\n'
            '• Portada de agenda sola en hoja carta, con marcas de corte.'),
      ],
    );
  }
}
