import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ai/fal_service.dart';
import '../ai/prompts.dart';
import '../app_settings.dart';
import '../export.dart';
import '../pdf/fonts.dart';
import '../pdf/postit_builder.dart';
import '../specs.dart';
import '../theme_spec.dart';
import 'widgets.dart';

class PostitScreen extends StatefulWidget {
  final AppSettings settings;
  final PostitSpec spec;
  const PostitScreen({super.key, required this.settings, required this.spec});

  @override
  State<PostitScreen> createState() => _PostitScreenState();
}

class _PostitScreenState extends State<PostitScreen> {
  static const titlePresets = ['', 'Compras', 'Plan de comidas', 'Pendientes', 'Notas', 'Esta semana', 'Recordar'];

  String _styleId = 'kawaii';
  String _concept = '';
  String _extra = '';
  String _title = '';
  PostitContent _content = PostitContent.ruled;
  int _sheets = 1;
  Uint8List? _frame;
  bool _busy = false;
  bool _busyExport = false;

  final _titleCtrl = TextEditingController();

  StyleSpec get _style => StyleSpec.byId(_styleId);
  PostitSpec get p => widget.spec;

  @override
  void didUpdateWidget(covariant PostitScreen old) {
    super.didUpdateWidget(old);
    if (old.spec.id != widget.spec.id) {
      setState(() => _frame = null);
      if (widget.spec.id == 'vertical' && _content == PostitContent.ruled) _content = PostitContent.checklist;
    }
  }

  Future<void> _generate() async {
    if (!widget.settings.isConfigured) {
      toast(context, 'Pon tu API key de fal.ai en Ajustes.');
      return;
    }
    setState(() => _busy = true);
    try {
      final ai = FalService(apiKey: widget.settings.falKey, textModel: widget.settings.falModel);
      final prompt = Prompts.postitFrame(
        style: _style, concept: _concept, extra: _extra, horizontal: p.w > p.h);
      final img = await ai.textToImage(prompt, width: int.parse(p.aiWidth), height: int.parse(p.aiHeight));
      setState(() => _frame = img);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (_frame == null) {
      toast(context, 'Genera el marco primero.');
      return;
    }
    setState(() => _busyExport = true);
    try {
      final fonts = await PdfFonts.load();
      final job = PostitJob(
        spec: p, style: _style, title: _title.trim(), content: _content, frameArt: _frame!, sheets: _sheets);
      final bytes = await PostitBuilder(job, fonts).build();
      final t = _title.trim().isEmpty ? 'sin_titulo' : _title.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      await exportPdf(bytes, 'Postit_${p.id}_${t}_carta.pdf');
      if (mounted) toast(context, 'PDF exportado.');
    } catch (e) {
      if (mounted) toast(context, 'Error al exportar: $e');
    } finally {
      if (mounted) setState(() => _busyExport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    final form = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(p.label, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('${p.perSheet} por hoja carta, con marcas de corte. La IA dibuja el marco y el personaje; la pauta y el título los pone la app.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        const SectionTitle('Estilo'),
        StyleChips(selected: _styleId, onChanged: (v) => setState(() => _styleId = v)),
        const SizedBox(height: 16),
        Field('Concepto', 'gatitos · cocina · plantas · profesora…', (v) => _concept = v, icon: Icons.lightbulb_outline),
        Field('Indicaciones extra (opcional)', 'más flores, colores menta…', (v) => _extra = v, maxLines: 2),
        const SectionTitle('Título del bloque'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in titlePresets)
            ChoiceChip(
              label: Text(t.isEmpty ? 'Sin título' : t),
              selected: _title == t,
              onSelected: (_) => setState(() { _title = t; _titleCtrl.text = t; }),
            ),
        ]),
        const SizedBox(height: 8),
        Field('Otro título', 'Escribe el tuyo', (v) => setState(() => _title = v), controller: _titleCtrl),
        const SectionTitle('Contenido'),
        DropdownButtonFormField<PostitContent>(
          value: _content,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [for (final e in postitContentLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _content = v ?? _content),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Hojas carta a exportar'),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _sheets,
            items: [for (var i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i'))],
            onChanged: (v) => setState(() => _sheets = v ?? 1),
          ),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _generate,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_frame == null ? 'Generar marco con IA' : 'Regenerar marco'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: (_busyExport || _frame == null) ? null : _export,
          icon: _busyExport
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar PDF (hoja carta)'),
        ),
      ],
    );

    final preview = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ArtPreview(label: 'Marco generado', bytes: _frame, busy: _busy, height: 420),
        Text('La pauta (${postitContentLabels[_content]}) y el título "${_title.isEmpty ? 'sin título' : _title}" se agregan al exportar.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    if (!wide) {
      return ListView(children: [
        SizedBox(height: 720, child: form),
        const Divider(),
        SizedBox(height: 520, child: preview),
      ]);
    }
    return Row(children: [
      Expanded(flex: 5, child: form),
      const VerticalDivider(width: 1),
      Expanded(flex: 4, child: preview),
    ]);
  }
}
