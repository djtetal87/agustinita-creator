import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _kFalKey = 'fal_key';
  static const _kFalModel = 'fal_model';
  static const _kScript = 'title_script';
  static const _kTitleStyle = 'title_style';
  static const _kInk = 'ink_hex';

  static const falModels = <String, String>{
    'fal-ai/flux-pro/v1.1': 'Flux Pro 1.1 — mejor calidad, ~4 ¢',
    'fal-ai/flux/dev': 'Flux Dev — más barato, ~2,5 ¢',
    'fal-ai/flux/schnell': 'Flux Schnell — borradores, ~0,3 ¢',
  };

  String falKey;
  String falModel;
  String titleScript; // stylescript · marck · parisienne · sacramento · allura
  String titleStyle; // dual · script · plain
  String inkHex; // color del texto del papel, '' = paleta del estilo
  AppSettings({required this.falKey, required this.falModel, this.titleScript = 'stylescript', this.titleStyle = 'dual', this.inkHex = '#6B4A7E'});

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      falKey: p.getString(_kFalKey) ?? '',
      falModel: p.getString(_kFalModel) ?? 'fal-ai/flux-pro/v1.1',
      titleScript: p.getString(_kScript) ?? 'stylescript',
      titleStyle: p.getString(_kTitleStyle) ?? 'dual',
      inkHex: p.getString(_kInk) ?? '#6B4A7E',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kFalKey, falKey.trim());
    await p.setString(_kFalModel, falModel);
    await p.setString(_kScript, titleScript);
    await p.setString(_kTitleStyle, titleStyle);
    await p.setString(_kInk, inkHex);
  }

  bool get isConfigured => falKey.trim().isNotEmpty;
}
