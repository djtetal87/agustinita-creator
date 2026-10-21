import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _kFalKey = 'fal_key';
  static const _kFalModel = 'fal_model';

  static const falModels = <String, String>{
    'fal-ai/flux-pro/v1.1': 'Flux Pro 1.1 — mejor calidad, ~4 ¢',
    'fal-ai/flux/dev': 'Flux Dev — más barato, ~2,5 ¢',
    'fal-ai/flux/schnell': 'Flux Schnell — borradores, ~0,3 ¢',
  };

  String falKey;
  String falModel;
  AppSettings({required this.falKey, required this.falModel});

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      falKey: p.getString(_kFalKey) ?? '',
      falModel: p.getString(_kFalModel) ?? 'fal-ai/flux-pro/v1.1',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kFalKey, falKey.trim());
    await p.setString(_kFalModel, falModel);
  }

  bool get isConfigured => falKey.trim().isNotEmpty;
}
