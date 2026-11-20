import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data.dart';
import 'extra.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final store = Store();
  await store.load();
  runApp(KakeoApp(store));
}

class KakeoApp extends StatefulWidget {
  final Store store;
  const KakeoApp(this.store, {super.key});
  @override
  State<KakeoApp> createState() => _KakeoAppState();
}

class _KakeoAppState extends State<KakeoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) widget.store.lockNow();
    if (state == AppLifecycleState.resumed) widget.store.applyRecurring();
  }

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C4DFF), secondary: const Color(0xFF00B8D4), tertiary: const Color(0xFFFF4081), brightness: b),
        inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kakeo',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        builder: (context, child) => ListenableBuilder(
          listenable: widget.store,
          builder: (_, __) => Stack(children: [child!, if (widget.store.locked) Positioned.fill(child: LockScreen(widget.store))]),
        ),
        home: Shell(widget.store),
      );
}

class Shell extends StatefulWidget {
  final Store store;
  const Shell(this.store, {super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [HomeScreen(widget.store), StatsScreen(widget.store), SettingsScreen(widget.store)];
    return Scaffold(
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(i), child: pages[i]))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAdd(context, widget.store),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Resumen'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Análisis'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
