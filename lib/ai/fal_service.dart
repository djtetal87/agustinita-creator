import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// fal.ai (Flux) — misma cola que usa Flyer GPTetal.
///  - texto → imagen: modelo Flux elegido (por defecto Flux Pro 1.1)
///  - foto → personaje / imagen guiada: Flux Kontext
class FalService {
  final String apiKey;
  final String textModel;
  FalService({required this.apiKey, this.textModel = 'fal-ai/flux-pro/v1.1'});

  static const _kontext = 'fal-ai/flux-pro/kontext';

  Map<String, String> get _headers => {
        'Authorization': 'Key $apiKey',
        'Content-Type': 'application/json',
      };

  /// Genera una imagen de [width]×[height] px.
  Future<Uint8List> textToImage(String prompt, {required int width, required int height}) {
    return _run(textModel, {
      'prompt': prompt,
      'image_size': {'width': width, 'height': height},
      'num_images': 1,
      'output_format': 'png',
      'enable_safety_checker': false,
    });
  }

  /// Transforma una foto (o usa una imagen de referencia) con Kontext.
  Future<Uint8List> imageToImage(String prompt, Uint8List image, {String aspectRatio = '1:1'}) {
    return _run(_kontext, {
      'prompt': prompt,
      'image_url': 'data:image/png;base64,${base64Encode(image)}',
      'aspect_ratio': aspectRatio,
      'output_format': 'png',
    });
  }

  Future<Uint8List> _run(String model, Map<String, dynamic> body) async {
    if (apiKey.isEmpty) throw AiException('Falta la API key de fal.ai (Ajustes).');
    final submit = await http
        .post(Uri.parse('https://queue.fal.run/$model'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(minutes: 1));
    if (submit.statusCode != 200 && submit.statusCode != 202) throw AiException(_err(submit));
    final sj = jsonDecode(submit.body) as Map<String, dynamic>;
    final statusUrl = sj['status_url'] as String?;
    final responseUrl = sj['response_url'] as String?;
    if (statusUrl == null || responseUrl == null) throw AiException('fal.ai no devolvió request_id.');

    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      final st = await http.get(Uri.parse(statusUrl), headers: _headers);
      if (st.statusCode != 200 && st.statusCode != 202) throw AiException(_err(st));
      final s = (jsonDecode(st.body) as Map<String, dynamic>)['status'];
      if (s == 'COMPLETED') break;
      if (s == 'FAILED' || s == 'CANCELLED') throw AiException('fal.ai: el pedido falló ($s).');
      if (DateTime.now().isAfter(deadline)) throw AiException('fal.ai tardó demasiado.');
    }

    final res = await http.get(Uri.parse(responseUrl), headers: _headers);
    if (res.statusCode != 200) throw AiException(_err(res));
    final rj = jsonDecode(res.body) as Map<String, dynamic>;
    final images = (rj['images'] as List?) ?? [];
    if (images.isEmpty) throw AiException('fal.ai no devolvió imagen.');
    final img = await http.get(Uri.parse(images.first['url'] as String)).timeout(const Duration(minutes: 2));
    if (img.statusCode != 200) throw AiException('No se pudo bajar la imagen.');
    return img.bodyBytes;
  }

  static String _err(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      final d = j['detail'];
      if (d is String) return 'fal.ai: $d';
      if (d is List && d.isNotEmpty) return 'fal.ai: ${d.first['msg'] ?? d.first}';
      if (j['error'] != null) return 'fal.ai: ${j['error']}';
    } catch (_) {}
    return 'fal.ai error ${r.statusCode}';
  }
}
