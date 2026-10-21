import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
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
  // iPad exige un origen para la hoja de compartir.
  await Share.shareXFiles([XFile(f.path)],
      text: suggestedName, sharePositionOrigin: const Rect.fromLTWH(40, 80, 200, 200));
  return f.path;
}

/// Elige una imagen (foto de referencia).
Future<Uint8List?> pickImage() async {
  if (!kIsWeb && Platform.isIOS) {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return null;
    return x.readAsBytes();
  }
  final x = await openFile(acceptedTypeGroups: const [
    XTypeGroup(label: 'Imágenes', extensions: ['png', 'jpg', 'jpeg', 'heic', 'webp']),
  ]);
  if (x == null) return null;
  return x.readAsBytes();
}
