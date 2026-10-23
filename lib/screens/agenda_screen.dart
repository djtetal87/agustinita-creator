import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ai/fal_service.dart';
import '../ai/prompts.dart';
import '../app_settings.dart';
import '../export.dart';
import '../pdf/agenda_builder.dart';
import '../pdf/fonts.dart';
import '../planner/sections.dart';
import 'package:printing/printing.dart';
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
  final _colorsC = TextEditingController();
  String get _colors {
    if (_colorsC.text.trim().isNotEmpty) return _colorsC.text;
    final hex = widget.settings.inkHex;
    if (hex.isEmpty) return '';
    final name = StyleSpec.inkPresets.entries
        .where((e) => '#${e.value.toRadixString(16).substring(2).toUpperCase()}' == hex.toUpperCase())
        .map((e) => e.key)
        .firstOrNull;
    return 'tonos de ${name?.toLowerCase() ?? hex}, blanco y beige suave';
  }
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
  String _sepMode = 'uno'; // uno · propias · estacion · mes
  final Map<int, Uint8List> _sepByMonth = {};
  int _sepProgress = 0;
  // personaje sobre las páginas
  bool _ovEnabled = true;
  String _ovCorner = 'br';
  double _ovSize = 0.18;
  double _ovOpacity = 0.30;
  bool _busyPreview = false;
  bool _mirrorBack = true;
  bool _singlePages = true;
  bool _fullBleedArt = true;
  bool _bleed = false;

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
  /// Estilo con la paleta derivada del color de tinta elegido (si hay).
  StyleSpec get _style {
    final base = StyleSpec.byId(_styleId);
    final ink = StyleSpec.parseHex(widget.settings.inkHex);
    return ink == null ? base : base.withInk(ink);
  }
  List<Color> _coverColors = const [];

  Future<void> _refreshCoverColors() async {
    final src = _cover;
    if (src == null) { setState(() => _coverColors = const []); return; }
    await prepareImageForColors(src);
    if (mounted) setState(() => _coverColors = dominantColors(src));
  }

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
          style: _style, concept: _concept, extra: _extra, colors: _colors, hasCharacter: _character != null);
      final img = _character != null
          ? await _ai.imageToImage(prompt, _character!, aspectRatio: '2:3')
          : await _ai.textToImage(prompt, width: AgendaSpec.byId(_sizeId).aiWidth, height: AgendaSpec.byId(_sizeId).aiHeight);
      setState(() => _cover = img);
      await _refreshCoverColors();
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
    await _refreshCoverColors();
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
            Prompts.interiorFromCover(concept: _concept, extra: extra, colors: _colors), _cover!, aspectRatio: '2:3');
      } else {
        final prompt = Prompts.agendaInteriorFrame(
            style: _style, concept: _concept, extra: extra, colors: _colors, hasCharacter: _character != null);
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
      final prompt = Prompts.monthDivider(style: _style, concept: _concept, extra: _extra, colors: _colors, fromCover: ref != null);
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

  Future<Uint8List> _genOneSeparator(String hint) async {
    final ref = (_coverUploaded || _styleId == 'referencia') ? _cover : _character;
    final prompt = Prompts.monthDivider(style: _style, concept: _concept, extra: _extra, colors: _colors, fromCover: ref != null, seasonHint: hint);
    final spec = AgendaSpec.byId(_sizeId);
    return ref != null
        ? await _ai.imageToImage(prompt, ref, aspectRatio: '2:3')
        : await _ai.textToImage(prompt, width: spec.aiWidth, height: spec.aiHeight);
  }

  /// 4 por estación o 12 por mes.
  Future<void> _genSeparatorsMulti() async {
    if (!_check()) return;
    setState(() { _busySeparator = true; _sepProgress = 0; });
    try {
      if (_sepMode == 'estacion') {
        const seasonOfMonth = [0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 0]; // ene..dic
        final imgs = <int, Uint8List>{};
        for (var sIdx = 0; sIdx < 4; sIdx++) {
          imgs[sIdx] = await _genOneSeparator(Prompts.seasonHints[sIdx]);
          setState(() => _sepProgress = sIdx + 1);
        }
        for (var m = 1; m <= 12; m++) {
          _sepByMonth[m] = imgs[seasonOfMonth[m - 1]]!;
        }
      } else {
        for (var m = 1; m <= 12; m++) {
          _sepByMonth[m] = await _genOneSeparator(Prompts.monthHints[m - 1]);
          setState(() => _sepProgress = m);
        }
      }
      setState(() => _separator = _sepByMonth[1]);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busySeparator = false);
    }
  }

  Future<void> _pickSeparator(int month) async {
    final b = await pickImage();
    if (b != null) setState(() => _sepByMonth[month] = b);
  }

  Future<void> _preview() async {
    setState(() => _busyPreview = true);
    try {
      final job = _job(await PdfFonts.load(script: widget.settings.titleScript, titleStyle: TitleStyle.values.byName(widget.settings.titleStyle)));
      final b = AgendaBuilder(job, await PdfFonts.load(script: widget.settings.titleScript, titleStyle: TitleStyle.values.byName(widget.settings.titleStyle)));
      final pdf = await b.buildInterior();
      final total = _singlePages ? (job.plannerPages?.length ?? 0) : ((job.plannerPages?.length ?? 0) / 2).ceil();
      final want = <int>{0, 1, 2, 3, total ~/ 2, (total ~/ 2) + 1, total - 2, total - 1}
          .where((i) => i >= 0 && i < total).toList()..sort();
      final imgs = <Uint8List>[];
      await for (final page in Printing.raster(pdf, pages: want, dpi: 60)) {
        imgs.add(await page.toPng());
      }
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Vista previa (${imgs.length} ${_singlePages ? 'páginas' : 'hojas'} de $total)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 360,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (var i = 0; i < imgs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(children: [
                        Expanded(child: InteractiveViewer(child: Image.memory(imgs[i]))),
                        Text('${_singlePages ? 'Pág.' : 'Hoja'} ${want[i] + 1}', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
            ]),
          ),
        ),
      );
    } catch (e) {
      if (mounted) toast(context, 'Vista previa: $e');
    } finally {
      if (mounted) setState(() => _busyPreview = false);
    }
  }

  AgendaJob _job(PdfFonts fonts) => AgendaJob(
        name: _name.trim(),
        phrase: _phrase.trim(),
        style: _style,
        plannerPages: _plannerPages(),
        separatorArt: _separator,
        separatorArts: _sepMode == 'uno' ? const {} : Map.of(_sepByMonth),
        coverArt: _cover,
        characterArt: _character,
        interiorArt: _illustratedInterior ? _interior : null,
        coverHasText: !_nameOnCover,
        mirrorBack: _mirrorBack,
        spec: AgendaSpec.byId(_sizeId),
        overlay: CharacterOverlay(enabled: _ovEnabled, corner: _ovCorner, sizePct: _ovSize, opacity: _ovOpacity),
        singlePages: _singlePages,
        fullBleedArt: _fullBleedArt,
        bleedMm: _bleed ? 3 : 0,
      );

  /// Flujo completo: personaje (si hay foto) → portada → marco interior → separadores.
  /// Si el usuario subió su propia portada, no se genera portada.
  Future<void> _generateAll() async {
    if (!_check()) return;
    if (_photo != null && _character == null) await _genCharacter();
    if (!_coverUploaded) await _genCover();
    if (_illustratedInterior) await _genInterior();
    if (_hasDividers) {
      if (_sepMode == 'estacion' || _sepMode == 'mes') {
        await _genSeparatorsMulti();
      } else if (_separator == null) {
        await _genSeparator();
      }
    }
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
      final fonts = await PdfFonts.load(script: widget.settings.titleScript, titleStyle: TitleStyle.values.byName(widget.settings.titleStyle));
      final job = _job(fonts);
      final b = AgendaBuilder(job, fonts);
      var slug = _name.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      if (slug.isEmpty) slug = 'sin_nombre';
      final interior = await b.buildInterior();
      final cover = await b.buildCover();
      // Los PDF ya están listos: el botón vuelve a la normalidad antes de abrir
      // la hoja de compartir (que puede quedarse abierta un rato).
      if (mounted) setState(() => _busyExport = false);
      final paths = await exportPdfs({
        (_singlePages ? 'Agenda_${slug}_Paginas_A5_DobleCara.pdf' : 'Agenda_${slug}_Interior_2xHoja.pdf'): interior,
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
        Field('Colores', 'rosado, beige, dorado suave · verde salvia y crema', (_) {}, icon: Icons.palette_outlined, controller: _colorsC),
        Text('Si lo llenas, la IA usa solo esos colores (manda sobre la paleta del estilo).', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Field('Indicaciones extra (opcional)', 'sin corazones, más flores…', (_) {}, maxLines: 2, controller: _extraC),
        const SectionTitle('Títulos'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Título a doble fuente'),
          subtitle: const Text('Primera palabra en negrita + resto en cursiva ("Fechas importantes"). Usa "|" en páginas extra para elegir el corte.'),
          value: widget.settings.titleStyle == 'dual',
          onChanged: (v) => setState(() { widget.settings.titleStyle = v ? 'dual' : 'script'; widget.settings.save(); }),
        ),
        if (widget.settings.titleStyle != 'dual')
          Row(children: [
            const Text('Sin doble fuente:'),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: widget.settings.titleStyle,
              items: const [
                DropdownMenuItem(value: 'script', child: Text('Todo en cursiva')),
                DropdownMenuItem(value: 'plain', child: Text('Todo en negrita')),
              ],
              onChanged: (v) => setState(() { widget.settings.titleStyle = v ?? 'script'; widget.settings.save(); }),
            ),
          ]),
        Text('Fuente cursiva', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in scriptFonts.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: widget.settings.titleScript == e.key,
              onSelected: (_) => setState(() { widget.settings.titleScript = e.key; widget.settings.save(); }),
            ),
        ]),
        const SizedBox(height: 12),
        InkPicker(
          hex: widget.settings.inkHex,
          fromCover: _coverColors,
          onChanged: (v) => setState(() { widget.settings.inkHex = v; widget.settings.save(); }),
        ),
        Text('Los adornos de la IA también siguen este color si "Colores" está vacío.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
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
          final sz = AgendaSpec.byId(_sizeId).id == 'a5';
          final txt = _singlePages
              ? 'Total: $n páginas ${sz ? 'A5' : 'media carta'} = $sheets hojas ${sz ? 'A5' : 'media carta'} impresas a doble cara'
              : 'Total: $n páginas = $sheets hojas ${sz ? 'A4' : 'carta'} a doble cara (2 páginas por cara, cortar al medio)';
          return Text(txt, style: Theme.of(context).textTheme.titleSmall);
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
        const SectionTitle('Personaje en las páginas con pauta'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Poner el personaje semitransparente'),
          subtitle: const Text('Va debajo de las líneas, en la esquina que elijas. El marco se genera sin personaje.'),
          value: _ovEnabled,
          onChanged: (v) => setState(() => _ovEnabled = v),
        ),
        if (_ovEnabled) ...[
          Row(children: [
            const Text('Esquina'),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _ovCorner,
              items: const [
                DropdownMenuItem(value: 'br', child: Text('Abajo derecha')),
                DropdownMenuItem(value: 'bl', child: Text('Abajo izquierda')),
                DropdownMenuItem(value: 'tr', child: Text('Arriba derecha')),
                DropdownMenuItem(value: 'tl', child: Text('Arriba izquierda')),
              ],
              onChanged: (v) => setState(() => _ovCorner = v ?? _ovCorner),
            ),
          ]),
          Row(children: [
            const SizedBox(width: 70, child: Text('Tamaño')),
            Expanded(child: Slider(value: _ovSize, min: 0.10, max: 0.30, divisions: 20,
                label: '${(_ovSize * 100).round()} %', onChanged: (v) => setState(() => _ovSize = v))),
            Text('${(_ovSize * 100).round()} %'),
          ]),
          Row(children: [
            const SizedBox(width: 70, child: Text('Opacidad')),
            Expanded(child: Slider(value: _ovOpacity, min: 0.10, max: 1.0, divisions: 18,
                label: '${(_ovOpacity * 100).round()} %', onChanged: (v) => setState(() => _ovOpacity = v))),
            Text('${(_ovOpacity * 100).round()} %'),
          ]),
        ],
        if (_hasDividers) ...[
          const SectionTitle('Separadores de mes'),
          DropdownButtonFormField<String>(
            value: _sepMode,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 'uno', child: Text('Una imagen para todos los meses (1 imagen)')),
              DropdownMenuItem(value: 'propias', child: Text('Mis imágenes o fotos (una por mes)')),
              DropdownMenuItem(value: 'estacion', child: Text('IA por estación (4 imágenes, ~16 ¢)')),
              DropdownMenuItem(value: 'mes', child: Text('IA por mes (12 imágenes, ~48 ¢)')),
            ],
            onChanged: (v) => setState(() => _sepMode = v ?? _sepMode),
          ),
          const SizedBox(height: 8),
          if (_sepMode == 'propias') ...[
            Text('Toca un mes para elegir su imagen. Los vacíos usan el arte generado.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var m = 1; m <= 12; m++)
                GestureDetector(
                  onTap: () => _pickSeparator(m),
                  onLongPress: () => setState(() => _sepByMonth.remove(m)),
                  child: Container(
                    width: 64, height: 84,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                      image: _sepByMonth[m] == null ? null : DecorationImage(image: MemoryImage(_sepByMonth[m]!), fit: BoxFit.cover),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      width: double.infinity,
                      child: Text(const ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'][m - 1],
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
            ]),
            Text('Mantén presionado para quitar una imagen.', style: Theme.of(context).textTheme.bodySmall),
          ],
          if ((_sepMode == 'estacion' || _sepMode == 'mes') && _busySeparator)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text('Generando separadores… $_sepProgress / ${_sepMode == 'estacion' ? 4 : 12}'),
              ]),
            ),
        ],
        const SectionTitle('Formato del PDF'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Una página por hoja (para doble cara)'),
          subtitle: Text(_singlePages
              ? 'Cada hoja del PDF es una página ${AgendaSpec.byId(_sizeId).id == 'a5' ? 'A5' : 'media carta'}. Imprime a doble cara, sin cortar.'
              : 'Dos páginas por hoja ${AgendaSpec.byId(_sizeId).id == 'a5' ? 'A4' : 'carta'} horizontal, para cortar al medio.'),
          value: _singlePages,
          onChanged: (v) => setState(() => _singlePages = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ilustración a página completa'),
          subtitle: const Text('El fondo cubre toda la hoja; las pautas quedan en el área segura (20 mm lado anillado, 10 mm exterior). Apágalo para el marco redondeado clásico.'),
          value: _fullBleedArt,
          onChanged: (v) => setState(() => _fullBleedArt = v),
        ),
        if (_singlePages)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Agregar sangrado 3 mm + marcas de corte'),
            subtitle: const Text('Apagado: PDF A5 exacto para hoja A5 lista. Enciéndelo si imprimes en hoja más grande y recortas.'),
            value: _bleed,
            onChanged: (v) => setState(() => _bleed = v),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Anillos al lado contrario en el reverso'),
          subtitle: const Text('Encendido: al imprimir a doble cara, el anillado queda siempre en el mismo borde físico. Apágalo solo si imprimes una cara.'),
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
          onPressed: _busyPreview ? null : _preview,
          icon: _busyPreview
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.preview),
          label: const Text('Vista previa (8 hojas)'),
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
            label: _sepMode == 'uno' ? 'Separadores de mes' : 'Separadores (enero)',
            bytes: _sepMode == 'uno' ? _separator : (_sepByMonth[1] ?? _separator),
            busy: _busySeparator,
            onRegenerate: _sepMode == 'propias' ? null : (_sepMode == 'uno' ? _genSeparator : _genSeparatorsMulti),
            height: 420,
          ),
    ];

    if (!wide) {
      // Celular / iPad vertical: todo en una sola lista, con la vista previa
      // justo debajo de los botones.
      final genIdx = formItems.length - 7; // antes del botón "Generar"
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
