import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Guarda un PDF: en Mac abre el diálogo "Guardar como"; en iPad lo escribe
/// en Documentos y abre la hoja de compartir (Archivos, AirDrop, WhatsApp).
Future<String?> exportPdf(Uint8List bytes, String suggestedName) async {
  if (!kIsWeb && Platform.isMacOS) {
    final loc = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
    );
    if (loc == null) return null;
    await File(loc.path).writeAsBytes(bytes);
    return loc.path;
  }
  final dir = await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/$suggestedName');
  await f.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(f.path)], text: suggestedName);
  return f.path;
}

/// Elige una imagen (foto de referencia).
Future<Uint8List?> pickImage() async {
  final x = await openFile(acceptedTypeGroups: const [
    XTypeGroup(label: 'Imágenes', extensions: ['png', 'jpg', 'jpeg', 'heic', 'webp']),
  ]);
  if (x == null) return null;
  return x.readAsBytes();
}
