import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'screens/agenda_screen.dart';
import 'screens/postit_screen.dart';
import 'screens/settings_screen.dart';
import 'specs.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgustinitaApp());
}

class AgustinitaApp extends StatelessWidget {
  const AgustinitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFF69B4);
    return MaterialApp(
      title: 'Agustinita Creator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: pink),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  AppSettings? _settings;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    AppSettings.load().then((s) => setState(() {
          _settings = s;
          if (!s.isConfigured) _index = 4;
        }));
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final pages = [
      AgendaScreen(settings: s),
      PostitScreen(settings: s, spec: PostitSpec.square),
      PostitScreen(settings: s, spec: PostitSpec.horizontal),
      PostitScreen(settings: s, spec: PostitSpec.vertical),
      SettingsScreen(settings: s, onSaved: () => setState(() {})),
    ];

    final wide = MediaQuery.of(context).size.width > 700;
    final dest = const [
      (Icons.menu_book_outlined, Icons.menu_book, 'Agenda'),
      (Icons.crop_square_outlined, Icons.crop_square, 'Post-it cuadrado'),
      (Icons.crop_landscape_outlined, Icons.crop_landscape, 'Post-it horizontal'),
      (Icons.crop_portrait_outlined, Icons.crop_portrait, 'Post-it vertical'),
      (Icons.settings_outlined, Icons.settings, 'Ajustes'),
    ];

    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.asset('assets/icon.png', width: 44),
            ),
            destinations: [
              for (final d in dest)
                NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Agustinita Creator')),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in dest)
            NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3.replaceAll('Post-it ', '')),
        ],
      ),
    );
  }
}
