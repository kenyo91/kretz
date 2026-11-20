import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'data.dart';
import 'screens.dart';

class PinPad extends StatefulWidget {
  final String title;
  final String? error;
  final ValueChanged<String> onDone;
  const PinPad({super.key, required this.title, required this.onDone, this.error});
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String pin = '';

  void tap(String d) {
    if (pin.length >= 4) return;
    setState(() => pin += d);
    if (pin.length == 4) {
      final p = pin;
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => pin = '');
        widget.onDone(p);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget key(String t) => SizedBox(
          width: 78,
          height: 78,
          child: t.isEmpty
              ? null
              : TextButton(
                  style: TextButton.styleFrom(shape: const CircleBorder()),
                  onPressed: () => t == '⌫' ? setState(() { if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1); }) : tap(t),
                  child: Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                ),
        );
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.lock_rounded, size: 44, color: cs.primary),
      const SizedBox(height: 12),
      Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
      SizedBox(height: 28, child: widget.error == null ? null : Center(child: Text(widget.error!, style: const TextStyle(color: coral)))),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 4; i++) Container(margin: const EdgeInsets.all(8), width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, color: i < pin.length ? cs.primary : cs.onSurface.withAlpha(40))),
      ]),
      const SizedBox(height: 28),
      for (final r in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', '⌫']]) Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final t in r) key(t)]),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  final Store s;
  const LockScreen(this.s, {super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? err;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: PinPad(
            title: 'Introduce tu PIN',
            error: err,
            onDone: (p) {
              if (widget.s.checkPin(p)) {
                widget.s.unlock();
              } else {
                setState(() => err = 'PIN incorrecto');
              }
            },
          ),
        ),
      );
}

class PinSetupPage extends StatefulWidget {
  final Store s;
  const PinSetupPage(this.s, {super.key});
  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String? first, err;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Configurar PIN')),
        body: SafeArea(
          child: PinPad(
            title: first == null ? 'Elige un PIN de 4 dígitos' : 'Repite el PIN',
            error: err,
            onDone: (p) {
              if (first == null) {
                setState(() { first = p; err = null; });
              } else if (first == p) {
                widget.s.setPin(p);
                Navigator.pop(context);
              } else {
                setState(() { first = null; err = 'No coinciden, empieza de nuevo'; });
              }
            },
          ),
        ),
      );
}

class RecurringPage extends StatelessWidget {
  final Store s;
  const RecurringPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final f = money(s);
          return Scaffold(
            appBar: AppBar(title: const Text('Recurrentes')),
            body: s.rec.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Activa «Repetir cada mes» al añadir un movimiento y aparecerá aquí.', textAlign: TextAlign.center)))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    for (final r in s.rec)
                      ListTile(
                        leading: CircleAvatar(child: Icon(r.income ? Icons.payments_rounded : catOf(r.cat).icon)),
                        title: Text(r.note.isEmpty ? r.cat : r.note),
                        subtitle: Text('Día ${r.day} de cada mes · ${r.cat}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${r.income ? '+' : '−'}${f.format(r.amount)}', style: TextStyle(fontWeight: FontWeight.w700, color: r.income ? mint : null)),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => s.removeRec(r.id)),
                        ]),
                      ),
                  ]),
          );
        },
      );
}

class CategoriesPage extends StatelessWidget {
  final Store s;
  const CategoriesPage(this.s, {super.key});

  Future<void> _add(BuildContext c) async {
    final name = TextEditingController();
    var g = 1, ic = 0;
    await showDialog(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Nueva categoría'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: [for (var i = 0; i < 4; i++) ChoiceChip(label: Text(groupLabels[i]), selected: g == i, onSelected: (_) => set(() => g = i))]),
              const SizedBox(height: 12),
              Wrap(spacing: 4, children: [for (var i = 0; i < iconPalette.length; i++) IconButton(isSelected: ic == i, icon: Icon(iconPalette[i]), onPressed: () => set(() => ic = i))]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty || allCats.any((k) => k.name.toLowerCase() == n.toLowerCase())) return;
                s.addCat(Cat(n, g, iconPalette[ic], ic));
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: s,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Mis categorías')),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(context), icon: const Icon(Icons.add_rounded), label: const Text('Nueva')),
          body: s.custom.isEmpty
              ? const Center(child: Text('Aún no has creado categorías.'))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final k in s.custom)
                    ListTile(
                      leading: CircleAvatar(backgroundColor: groupColors[k.group].withAlpha(45), child: Icon(k.icon, color: groupColors[k.group])),
                      title: Text(k.name),
                      subtitle: Text(groupLabels[k.group]),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => s.removeCat(k.name)),
                    ),
                ]),
        ),
      );
}
