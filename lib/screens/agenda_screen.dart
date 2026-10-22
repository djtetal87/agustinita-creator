import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ai/fal_service.dart';
import '../ai/prompts.dart';
import '../app_settings.dart';
import '../export.dart';
import '../pdf/agenda_builder.dart';
import '../pdf/fonts.dart';
import '../planner/sections.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
  // Controladores persistentes: así los campos no se borran al redibujar.
  final _nameC = TextEditingController();
  final _phraseC = TextEditingController();
  final _conceptC = TextEditingController();
  final _extraC = TextEditingController();
  final _interiorExtraC = TextEditingController();
  final _customPagesC = TextEditingController();
  String get _name => _nameC.text;
  String get _phrase => _phraseC.text;
  String get _concept => _conceptC.text;
  String get _extra => _extraC.text;
  String get _interiorExtra => _interiorExtraC.text;
  String get _customPages => _customPagesC.text;
  String _styleId = 'kawaii';
  String _sizeId = 'a5';
  bool _nameOnCover = true; // escribir nombre y frase sobre la portada
  int _year = DateTime.now().year + 1;
  int _startMonth = 1;
  int _monthsCount = 12;
  String _templateId = 'psicologa';
  late List<SectionChoice> _sections = plannerTemplates.first.build();
  Uint8List? _separator;
  bool _busySeparator = false;
  bool _mirrorBack = false;

  Uint8List? _photo;
  Uint8List? _character;
  Uint8List? _cover;
  bool _coverUploaded = false; // portada hecha en otra app
  Uint8List? _interior;
  bool _illustratedInterior = true;
  bool _busyCharacter = false;
  bool _busyCover = false;
  bool _busyInterior = false;
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
          : await _ai.textToImage(prompt, width: AgendaSpec.byId(_sizeId).aiWidth, height: AgendaSpec.byId(_sizeId).aiHeight);
      setState(() => _cover = img);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busyCover = false);
    }
  }

  Future<void> _uploadCover() async {
    final b = await pickImage();
    if (b == null) return;
    setState(() {
      _cover = b;
      _coverUploaded = true;
      _nameOnCover = false;
    });
  }

  Future<void> _genInterior() async {
    if (!_check()) return;
    setState(() => _busyInterior = true);
    try {
      final extra = [_extra, _interiorExtra].where((e) => e.trim().isNotEmpty).join('. ');
      Uint8List img;
      if ((_coverUploaded || _styleId == 'referencia') && _cover != null) {
        // interior basado en la portada que subió el usuario
        img = await _ai.imageToImage(
            Prompts.interiorFromCover(concept: _concept, extra: extra), _cover!, aspectRatio: '2:3');
      } else {
        final prompt = Prompts.agendaInteriorFrame(
            style: _style, concept: _concept, extra: extra, hasCharacter: _character != null);
        img = _character != null
            ? await _ai.imageToImage(prompt, _character!, aspectRatio: '2:3')
            : await _ai.textToImage(prompt, width: AgendaSpec.byId(_sizeId).aiWidth, height: AgendaSpec.byId(_sizeId).aiHeight);
      }
      setState(() => _interior = img);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busyInterior = false);
    }
  }

  bool get _hasDividers => _sections.any((c) => c.enabled && c.kind == SectionKind.monthDivider);

  Future<void> _genSeparator() async {
    if (!_check()) return;
    setState(() => _busySeparator = true);
    try {
      final ref = (_coverUploaded || _styleId == 'referencia') ? _cover : _character;
      final prompt = Prompts.monthDivider(style: _style, concept: _concept, extra: _extra, fromCover: ref != null);
      final spec = AgendaSpec.byId(_sizeId);
      final img = ref != null
          ? await _ai.imageToImage(prompt, ref, aspectRatio: '2:3')
          : await _ai.textToImage(prompt, width: spec.aiWidth, height: spec.aiHeight);
      setState(() => _separator = img);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busySeparator = false);
    }
  }

  /// Flujo completo: personaje (si hay foto) → portada → marco interior → separadores.
  /// Si el usuario subió su propia portada, no se genera portada.
  Future<void> _generateAll() async {
    if (!_check()) return;
    if (_photo != null && _character == null) await _genCharacter();
    if (!_coverUploaded) await _genCover();
    if (_illustratedInterior) await _genInterior();
    if (_hasDividers) await _genSeparator();
  }

  List<PlannerPage> _plannerPages() => buildPlannerPages(
        choices: _sections,
        year: _year,
        monthsFrom: _startMonth,
        monthsCount: _monthsCount,
        custom: CustomPage.parse(_customPages),
      );

  void _applyTemplate(String id) {
    setState(() {
      _templateId = id;
      _sections = plannerTemplates.firstWhere((t) => t.id == id).build();
    });
  }

  Future<void> _copyQuestionnaire() async {
    await Clipboard.setData(ClipboardData(text: questionnaire()));
    if (mounted) toast(context, 'Cuestionario copiado. Pégalo en WhatsApp.');
  }

  Future<void> _export() async {
    setState(() => _busyExport = true);
    try {
      final fonts = await PdfFonts.load();
      final job = AgendaJob(
        name: _name.trim(),
        phrase: _phrase.trim(),
        style: _style,
        plannerPages: _plannerPages(),
        separatorArt: _separator,
        coverArt: _cover,
        characterArt: _character,
        interiorArt: _illustratedInterior ? _interior : null,
        coverHasText: !_nameOnCover,
        mirrorBack: _mirrorBack,
        spec: AgendaSpec.byId(_sizeId),
      );
      final b = AgendaBuilder(job, fonts);
      var slug = _name.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      if (slug.isEmpty) slug = 'sin_nombre';
      final interior = await b.buildInterior();
      final cover = await b.buildCover();
      // Los PDF ya están listos: el botón vuelve a la normalidad antes de abrir
      // la hoja de compartir (que puede quedarse abierta un rato).
      if (mounted) setState(() => _busyExport = false);
      final paths = await exportPdfs({
        'Agenda_${slug}_Interior_DobleCara.pdf': interior,
        'Agenda_${slug}_Portada.pdf': cover,
      });
      if (paths != null && mounted) toast(context, 'PDFs exportados (interior + portada).');
    } catch (e) {
      if (mounted) toast(context, 'Error al exportar: $e');
    } finally {
      if (mounted) setState(() => _busyExport = false);
    }
  }

  Widget _sectionRow(SectionChoice c) {
    final d = sectionDef(c.kind);
    final unit = d.placement == Placement.perMonth ? '/mes' : d.placement == Placement.perWeek ? '/sem' : '';
    final fixedDaily = c.kind == SectionKind.daily;
    return Row(children: [
      Checkbox(value: c.enabled, onChanged: (v) => setState(() => c.enabled = v ?? false)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.label, style: TextStyle(color: c.enabled ? null : Colors.grey)),
        Text(d.hint, style: Theme.of(context).textTheme.bodySmall),
      ])),
      if (!fixedDaily) ...[
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: c.enabled && c.pages > 1 ? () => setState(() => c.pages--) : null,
          icon: const Icon(Icons.remove_circle_outline, size: 18),
        ),
        Text('${c.pages}$unit', style: Theme.of(context).textTheme.labelLarge),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: c.enabled && c.pages < 40 ? () => setState(() => c.pages++) : null,
          icon: const Icon(Icons.add_circle_outline, size: 18),
        ),
      ] else
        Text('7/sem', style: Theme.of(context).textTheme.labelLarge),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    final formItems = <Widget>[
        Text('Agenda / planner anillado', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Interior doble cara (2 páginas por hoja) + portada en hoja aparte. Margen de anillos: 15 mm. A5 por defecto.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        Field('Nombre de la persona (opcional si la portada ya lo trae)', 'Agustina', (_) {}, icon: Icons.person, controller: _nameC),
        Field('Texto a decir (frase, opcional)', 'Sigue brillando cada día', (_) {}, icon: Icons.format_quote, controller: _phraseC),
        const SectionTitle('Estilo'),
        StyleChips(selected: _styleId, onChanged: (v) => setState(() => _styleId = v)),
        const SizedBox(height: 16),
        Field('Concepto', 'romántica · para profesora · para enfermero · amante de los gatos',
            (_) {}, icon: Icons.lightbulb_outline, controller: _conceptC),
        Field('Indicaciones extra (opcional)', 'fondo celeste, sin corazones…', (_) {}, maxLines: 2, controller: _extraC),
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
        const SectionTitle('Portada hecha en otra app (opcional)'),
        Row(children: [
          OutlinedButton.icon(
            onPressed: _uploadCover,
            icon: const Icon(Icons.upload_file),
            label: Text(_coverUploaded ? 'Cambiar portada' : 'Subir portada'),
          ),
          const SizedBox(width: 12),
          if (_coverUploaded) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_cover!, width: 40, height: 56, fit: BoxFit.cover),
            ),
            IconButton(
              onPressed: () => setState(() { _cover = null; _coverUploaded = false; }),
              icon: const Icon(Icons.close),
            ),
          ],
        ]),
        Text(_coverUploaded
            ? 'Se usa tal cual (sin escribir el nombre encima) y el marco interior se genera a partir de ella.'
            : 'Si subes tu portada, la IA no la genera y el interior se basa en tu diseño.',
            style: Theme.of(context).textTheme.bodySmall),
        const SectionTitle('Tamaño'),
        DropdownButtonFormField<String>(
          value: _sizeId,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: [for (final sp in AgendaSpec.all) DropdownMenuItem(value: sp.id, child: Text(sp.label))],
          onChanged: (v) => setState(() => _sizeId = v ?? _sizeId),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Escribir nombre y frase sobre la portada'),
          subtitle: Text(_coverUploaded
              ? 'Apágalo si tu portada ya trae el nombre.'
              : 'Banda al pie de la portada con el nombre y la frase.'),
          value: _nameOnCover,
          onChanged: (v) => setState(() => _nameOnCover = v),
        ),
        const SectionTitle('Secciones de la agenda'),
        DropdownButtonFormField<String>(
          value: _templateId,
          decoration: const InputDecoration(labelText: 'Plantilla', border: OutlineInputBorder(), isDense: true),
          items: [for (final t in plannerTemplates) DropdownMenuItem(value: t.id, child: Text(t.label))],
          onChanged: (v) { if (v != null) _applyTemplate(v); },
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Año'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _year,
            items: [for (var y = DateTime.now().year - 1; y <= DateTime.now().year + 3; y++)
              DropdownMenuItem(value: y, child: Text('$y'))],
            onChanged: (v) => setState(() => _year = v ?? _year),
          ),
          const SizedBox(width: 16),
          const Text('Desde'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _startMonth,
            items: [for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text(const ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'][m - 1]))],
            onChanged: (v) => setState(() => _startMonth = v ?? _startMonth),
          ),
          const SizedBox(width: 16),
          DropdownButton<int>(
            value: _monthsCount,
            items: [for (final n in [6, 12, 18]) DropdownMenuItem(value: n, child: Text('$n meses'))],
            onChanged: (v) => setState(() => _monthsCount = v ?? _monthsCount),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Marca las secciones y cuántas páginas de cada una (por mes o por semana cuando corresponde).',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        for (final c in _sections) _sectionRow(c),
        const SizedBox(height: 6),
        Builder(builder: (ctx) {
          final n = _plannerPages().length;
          final sheets = (n / 2).ceil();
          return Text('Total: $n páginas = $sheets hojas (${AgendaSpec.byId(_sizeId).id == 'a5' ? 'A4' : 'carta'} doble cara)',
              style: Theme.of(context).textTheme.titleSmall);
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _copyQuestionnaire,
          icon: const Icon(Icons.content_copy),
          label: const Text('Copiar cuestionario para la clienta'),
        ),
        const SizedBox(height: 8),
        Field(
          'Páginas extra (una por línea)',
          'Horario de clases: cuadrícula\nLista de cursos: lista numerada x2',
          (_) {},
          maxLines: 3,
          icon: Icons.playlist_add,
          controller: _customPagesC,
        ),
        Text('Pautas: rayado · caligrafía · checklist · cuadrícula · punteado · tabla · recuadro · lista numerada. "xN" repite la página N veces. Van antes de la página del nombre.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Interior ilustrado'),
          subtitle: const Text('Un marco decorado (suave, bordes) en todas las páginas, a juego con la portada. +1 imagen.'),
          value: _illustratedInterior,
          onChanged: (v) => setState(() => _illustratedInterior = v),
        ),
        if (_illustratedInterior)
          Field('Indicaciones para el interior (opcional)', 'solo flores, sin personaje · más suave que la portada',
              (_) {}, maxLines: 2, controller: _interiorExtraC),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Margen de anillos a la derecha en el reverso'),
          subtitle: const Text('Déjalo apagado para imprimir igual que la agenda de Agustina (margen a la izquierda en ambas caras).'),
          value: _mirrorBack,
          onChanged: (v) => setState(() => _mirrorBack = v),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (_busyCover || _busyCharacter || _busyInterior || _busySeparator) ? null : _generateAll,
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
          label: _coverUploaded ? 'Portada (subida)' : 'Portada',
          bytes: _cover,
          busy: _busyCover,
          onRegenerate: _coverUploaded ? null : _genCover,
          height: 420,
        ),
        if (_illustratedInterior)
          ArtPreview(
            label: 'Marco interior',
            bytes: _interior,
            busy: _busyInterior,
            onRegenerate: _genInterior,
            height: 420,
          ),
        if (_hasDividers)
          ArtPreview(
            label: 'Separadores de mes',
            bytes: _separator,
            busy: _busySeparator,
            onRegenerate: _genSeparator,
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
