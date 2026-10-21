import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ai/fal_service.dart';
import '../ai/prompts.dart';
import '../app_settings.dart';
import '../export.dart';
import '../pdf/agenda_builder.dart';
import '../pdf/fonts.dart';
import '../specs.dart';
import '../theme_spec.dart';
import 'widgets.dart';

class AgendaScreen extends StatefulWidget {
  final AppSettings settings;
  const AgendaScreen({super.key, required this.settings});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  String _name = '';
  String _phrase = '';
  String _styleId = 'kawaii';
  String _concept = '';
  String _extra = '';
  int _year = DateTime.now().year;
  bool _mirrorBack = false;

  Uint8List? _photo;
  Uint8List? _character;
  Uint8List? _cover;
  bool _busyCharacter = false;
  bool _busyCover = false;
  bool _busyExport = false;

  FalService get _ai => FalService(apiKey: widget.settings.falKey, textModel: widget.settings.falModel);
  StyleSpec get _style => StyleSpec.byId(_styleId);

  bool _check() {
    if (!widget.settings.isConfigured) {
      toast(context, 'Pon tu API key de fal.ai en Ajustes.');
      return false;
    }
    return true;
  }

  Future<void> _pickPhoto() async {
    final b = await pickImage();
    if (b != null) setState(() => _photo = b);
  }

  Future<void> _genCharacter() async {
    if (!_check() || _photo == null) return;
    setState(() => _busyCharacter = true);
    try {
      final img = await _ai.imageToImage(
        Prompts.photoToCharacter(style: _style, concept: _concept),
        _photo!,
        aspectRatio: '1:1',
      );
      setState(() => _character = img);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busyCharacter = false);
    }
  }

  Future<void> _genCover() async {
    if (!_check()) return;
    setState(() => _busyCover = true);
    try {
      final prompt = Prompts.agendaCover(
          style: _style, concept: _concept, extra: _extra, hasCharacter: _character != null);
      final img = _character != null
          ? await _ai.imageToImage(prompt, _character!, aspectRatio: '2:3')
          : await _ai.textToImage(prompt, width: 992, height: 1536);
      setState(() => _cover = img);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busyCover = false);
    }
  }

  /// Flujo completo: personaje (si hay foto) → portada.
  Future<void> _generateAll() async {
    if (!_check()) return;
    if (_photo != null && _character == null) await _genCharacter();
    await _genCover();
  }

  Future<void> _export() async {
    if (_name.trim().isEmpty) {
      toast(context, 'Falta el nombre.');
      return;
    }
    setState(() => _busyExport = true);
    try {
      final fonts = await PdfFonts.load();
      final job = AgendaJob(
        name: _name.trim(),
        phrase: _phrase.trim(),
        style: _style,
        pages: defaultAgendaPages(_year),
        coverArt: _cover,
        characterArt: _character,
        mirrorBack: _mirrorBack,
      );
      final b = AgendaBuilder(job, fonts);
      final slug = _name.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final interior = await b.buildInterior();
      final p1 = await exportPdf(interior, 'Agenda_${slug}_Interior_DobleCara.pdf');
      if (p1 == null) return;
      final cover = await b.buildCover();
      await exportPdf(cover, 'Agenda_${slug}_Portada.pdf');
      if (mounted) toast(context, 'PDFs exportados.');
    } catch (e) {
      if (mounted) toast(context, 'Error al exportar: $e');
    } finally {
      if (mounted) setState(() => _busyExport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    final formItems = <Widget>[
        Text('Agenda anillada 15 mm', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Interior doble cara (24 hojas, 48 páginas) + portada en hoja aparte. Margen de anillos: 15 mm.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        Field('Nombre de la persona', 'Agustina', (v) => _name = v, icon: Icons.person),
        Field('Texto a decir (frase)', 'Sigue brillando cada día', (v) => _phrase = v, icon: Icons.format_quote),
        const SectionTitle('Estilo'),
        StyleChips(selected: _styleId, onChanged: (v) => setState(() => _styleId = v)),
        const SizedBox(height: 16),
        Field('Concepto', 'romántica · para profesora · para enfermero · amante de los gatos',
            (v) => _concept = v, icon: Icons.lightbulb_outline),
        Field('Indicaciones extra (opcional)', 'fondo celeste, sin corazones…', (v) => _extra = v, maxLines: 2),
        const SectionTitle('Foto para convertir en personaje (opcional)'),
        Row(children: [
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_photo == null ? 'Elegir foto' : 'Cambiar foto'),
          ),
          const SizedBox(width: 12),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_photo!, width: 56, height: 56, fit: BoxFit.cover),
            ),
          if (_photo != null) ...[
            const SizedBox(width: 8),
            IconButton(onPressed: () => setState(() { _photo = null; _character = null; }), icon: const Icon(Icons.close)),
          ],
        ]),
        const SectionTitle('Páginas'),
        Row(children: [
          const Text('Calendarios desde el año'),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _year,
            items: [for (var y = DateTime.now().year - 1; y <= DateTime.now().year + 3; y++)
              DropdownMenuItem(value: y, child: Text('$y'))],
            onChanged: (v) => setState(() => _year = v ?? _year),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Margen de anillos a la derecha en el reverso'),
          subtitle: const Text('Déjalo apagado para imprimir igual que la agenda de Agustina (margen a la izquierda en ambas caras).'),
          value: _mirrorBack,
          onChanged: (v) => setState(() => _mirrorBack = v),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (_busyCover || _busyCharacter) ? null : _generateAll,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generar arte con IA'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busyExport ? null : _export,
          icon: _busyExport
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar PDFs (interior + portada)'),
        ),
        const SizedBox(height: 4),
        Text('Puedes exportar sin arte para revisar las páginas; la portada queda con fondo liso.',
            style: Theme.of(context).textTheme.bodySmall),
    ];

    final previewItems = <Widget>[
        ArtPreview(
          label: 'Personaje (foto → ilustración)',
          bytes: _character,
          busy: _busyCharacter,
          onRegenerate: _photo == null ? null : _genCharacter,
          height: 240,
        ),
        ArtPreview(
          label: 'Portada',
          bytes: _cover,
          busy: _busyCover,
          onRegenerate: _genCover,
          height: 420,
        ),
    ];

    if (!wide) {
      // Celular / iPad vertical: todo en una sola lista, con la vista previa
      // justo debajo de los botones.
      final genIdx = formItems.length - 5; // antes del botón "Generar"
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ...formItems.sublist(0, genIdx),
          ...previewItems,
          ...formItems.sublist(genIdx),
          const SizedBox(height: 24),
        ],
      );
    }
    return Row(children: [
      Expanded(flex: 5, child: ListView(padding: const EdgeInsets.all(20), children: formItems)),
      const VerticalDivider(width: 1),
      Expanded(flex: 4, child: ListView(padding: const EdgeInsets.all(20), children: previewItems)),
    ]);
  }
}
