import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'data.dart';
import 'extra.dart';

const brand = LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF00B8D4)], begin: Alignment.topLeft, end: Alignment.bottomRight);
const coral = Color(0xFFFF5252), mint = Color(0xFF00C896);

NumberFormat money(Store s) => NumberFormat.currency(locale: 'es', symbol: s.currency);

Widget panel(BuildContext c, String title, Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Theme.of(c).colorScheme.onSurface.withAlpha(14), borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        child,
      ]),
    );

Widget progress(double v, Color c) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 600),
      builder: (_, x, __) => ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: x, minHeight: 10, color: c, backgroundColor: c.withAlpha(40))),
    );

class MonthBar extends StatelessWidget {
  final Store s;
  const MonthBar(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = DateFormat.yMMMM('es').format(s.month);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton.filledTonal(onPressed: () => s.shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
      Text(t[0].toUpperCase() + t.substring(1), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      IconButton.filledTonal(onPressed: () => s.shift(1), icon: const Icon(Icons.chevron_right_rounded)),
    ]);
  }
}

class HomeScreen extends StatelessWidget {
  final Store s;
  const HomeScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final f = money(s), w = s.weekSpend, g = s.byGroup, tx = s.monthTx;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
            MonthBar(s),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(gradient: brand, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withAlpha(90), blurRadius: 24, offset: const Offset(0, 10))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Te queda este mes', style: TextStyle(color: Colors.white70)),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: s.left),
                  duration: const Duration(milliseconds: 700),
                  builder: (_, v, __) => Text(f.format(v), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _stat('Ingresos', f.format(s.income), Icons.south_west_rounded),
                  _stat('Ahorro', f.format(s.goal), Icons.savings_rounded),
                  _stat('Gastado', f.format(s.spent), Icons.north_east_rounded),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            panel(context, 'Gasto variable por semana', Column(children: [
              for (var i = 0; i < w.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Semana ${i + 1}'), Text('${f.format(w[i])} / ${f.format(s.allowance)}', style: const TextStyle(fontSize: 12))]),
                    const SizedBox(height: 4),
                    progress(s.allowance > 0 ? w[i] / s.allowance : (w[i] > 0 ? 1 : 0), w[i] > s.allowance ? coral : mint),
                  ]),
                ),
            ])),
            panel(context, 'Los cuatro cajones', s.spent == 0
                ? const Text('Registra un gasto para ver el reparto.')
                : Row(children: [
                    SizedBox(
                      height: 130,
                      width: 130,
                      child: PieChart(PieChartData(
                        centerSpaceRadius: 34,
                        sectionsSpace: 3,
                        sections: [for (var i = 0; i < 4; i++) if (g[i] > 0) PieChartSectionData(value: g[i], color: groupColors[i], radius: 22, showTitle: false)],
                      )),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(children: [
                      for (var i = 0; i < 4; i++)
                        Row(children: [
                          CircleAvatar(radius: 5, backgroundColor: groupColors[i]),
                          const SizedBox(width: 8),
                          Expanded(child: Text(groupLabels[i])),
                          Text(f.format(g[i]), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                    ])),
                  ])),
            panel(context, 'Últimos movimientos', tx.isEmpty
                ? const Text('Aún no hay movimientos. Pulsa Añadir.')
                : Column(children: [
                    for (final t in tx.take(10))
                      Dismissible(
                        key: ValueKey(t.id),
                        background: Container(color: coral, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete_rounded, color: Colors.white)),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          s.remove(t.id);
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(content: const Text('Movimiento borrado'), action: SnackBarAction(label: 'Deshacer', onPressed: () => s.add(t))));
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(backgroundColor: (t.income ? mint : groupColors[catOf(t.cat).group]).withAlpha(45), child: Icon(t.income ? Icons.payments_rounded : catOf(t.cat).icon, color: t.income ? mint : groupColors[catOf(t.cat).group])),
                          title: Text(t.note.isEmpty ? t.cat : t.note),
                          subtitle: Text('${DateFormat('d MMM', 'es').format(t.date)} · ${t.cat}${t.fixed ? ' · fijo' : ''}'),
                          trailing: Text('${t.income ? '+' : '−'}${f.format(t.amount)}', style: TextStyle(fontWeight: FontWeight.w700, color: t.income ? mint : null)),
                        ),
                      ),
                  ])),
          ]);
        },
      );

  Widget _stat(String l, String v, IconData i) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(i, size: 14, color: Colors.white70), const SizedBox(width: 4), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12))]),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
        ]),
      );
}

Future<void> showAdd(BuildContext c, Store s) => showModalBottomSheet(context: c, isScrollControlled: true, showDragHandle: true, builder: (_) => AddSheet(s));

class AddSheet extends StatefulWidget {
  final Store s;
  const AddSheet(this.s, {super.key});
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  bool income = false, fixed = false, repeat = false;
  String cat = 'Supermercado';
  DateTime date = DateTime.now();
  final amount = TextEditingController(), note = TextEditingController();

  void save() {
    final a = double.tryParse(amount.text.replaceAll(',', '.'));
    if (a == null || a <= 0) return;
    widget.s.add(Tx(id: DateTime.now().microsecondsSinceEpoch, income: income, amount: a, cat: income ? 'Ingreso' : cat, date: date, note: note.text.trim(), fixed: !income && fixed));
    if (repeat) widget.s.addRec(Rec(id: DateTime.now().microsecondsSinceEpoch + 1, income: income, amount: a, cat: income ? 'Ingreso' : cat, note: note.text.trim(), day: date.day, last: Store.key(date)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('Gasto'), icon: Icon(Icons.north_east_rounded)), ButtonSegment(value: true, label: Text('Ingreso'), icon: Icon(Icons.south_west_rounded))],
              selected: {income},
              onSelectionChanged: (v) => setState(() => income = v.first),
            ),
            TextField(
              controller: amount,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: income ? mint : null),
              decoration: InputDecoration(hintText: '0,00 ${widget.s.currency}', border: InputBorder.none),
            ),
            if (!income) ...[
              Wrap(spacing: 8, children: [
                for (final k in allCats)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 18, color: groupColors[k.group]),
                    label: Text(k.name),
                    selected: cat == k.name,
                    selectedColor: groupColors[k.group].withAlpha(60),
                    onSelected: (_) => setState(() => cat = k.name),
                  ),
              ]),
              if (services.containsKey(cat)) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [for (final n in services[cat]!) ActionChip(label: Text(n), onPressed: () => setState(() { note.text = n; fixed = true; }))]),
              ],
            ],
            const SizedBox(height: 12),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Nota (opcional)', prefixIcon: Icon(Icons.edit_note_rounded))),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: Text(DateFormat.yMMMMd('es').format(date)),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => date = d);
              },
            ),
            if (!income) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Gasto fijo'), subtitle: const Text('Alquiler, suscripciones…'), value: fixed, onChanged: (v) => setState(() => fixed = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Repetir cada mes'), subtitle: const Text('Se añadirá solo cada mes'), value: repeat, onChanged: (v) => setState(() => repeat = v)),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.check_rounded), label: const Text('Guardar'), style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)))),
          ]),
        ),
      );
}

class StatsScreen extends StatelessWidget {
  final Store s;
  const StatsScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final f = money(s);
          final ms = [for (var i = 5; i >= 0; i--) DateTime(s.month.year, s.month.month - i)];
          final top = allCats.where((c) => s.spentIn(c.name) > 0).toList()..sort((a, b) => s.spentIn(b.name).compareTo(s.spentIn(a.name)));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
            MonthBar(s),
            const SizedBox(height: 12),
            panel(context, 'Ingresos vs gastos (6 meses)', SizedBox(
              height: 200,
              child: BarChart(BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat.MMM('es').format(ms[v.toInt()]), style: const TextStyle(fontSize: 11))))),
                ),
                barGroups: [
                  for (var i = 0; i < ms.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: s.total(ms[i], true), color: mint, width: 10, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: s.total(ms[i], false), color: coral, width: 10, borderRadius: BorderRadius.circular(4)),
                    ]),
                ],
              )),
            )),
            panel(context, 'Dónde se va tu dinero', top.isEmpty
                ? const Text('Sin gastos este mes.')
                : Column(children: [
                    for (final c in top.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(children: [
                          Row(children: [
                            Icon(c.icon, size: 18, color: groupColors[c.group]),
                            const SizedBox(width: 8),
                            Expanded(child: Text(c.name)),
                            Text(s.budgets[c.name] != null && s.budgets[c.name]! > 0 ? '${f.format(s.spentIn(c.name))} / ${f.format(s.budgets[c.name])}' : f.format(s.spentIn(c.name)), style: const TextStyle(fontSize: 12)),
                          ]),
                          const SizedBox(height: 4),
                          progress(
                            (s.budgets[c.name] ?? 0) > 0 ? s.spentIn(c.name) / s.budgets[c.name]! : s.spentIn(c.name) / s.spent,
                            (s.budgets[c.name] ?? 0) > 0 && s.spentIn(c.name) > s.budgets[c.name]! ? coral : groupColors[c.group],
                          ),
                        ]),
                      ),
                  ])),
          ]);
        },
      );
}

class SettingsScreen extends StatelessWidget {
  final Store s;
  const SettingsScreen(this.s, {super.key});

  Future<void> _copy(BuildContext c, String t, String msg) async {
    await Clipboard.setData(ClipboardData(text: t));
    if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _restore(BuildContext c) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: c,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar copia'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Pega aquí la copia. Sustituirá los datos actuales.'), const SizedBox(height: 8), TextField(controller: ctrl, maxLines: 5)]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              try {
                s.importJson(ctrl.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Datos restaurados')));
              } catch (_) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('La copia no es válida')));
              }
            },
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData i, String t, VoidCallback f, {String? sub}) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(i), title: Text(t), subtitle: sub == null ? null : Text(sub), trailing: const Icon(Icons.chevron_right_rounded), onTap: f);

  Future<void> _budget(BuildContext c, Cat k) async {
    final ctrl = TextEditingController(text: (s.budgets[k.name] ?? 0) > 0 ? s.budgets[k.name].toString() : '');
    await showDialog(
      context: c,
      builder: (_) => AlertDialog(
        title: Text('Tope mensual · ${k.name}'),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '0 = sin tope')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () { s.setBudget(k.name, double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0); Navigator.pop(c); }, child: const Text('Guardar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final f = money(s);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
            MonthBar(s),
            const SizedBox(height: 12),
            panel(context, 'Ahorro objetivo del mes', TextFormField(
              key: ValueKey(Store.key(s.month)),
              initialValue: s.goal > 0 ? s.goal.toString() : '',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.savings_rounded), hintText: '0', suffixText: s.currency),
              onChanged: (v) => s.setGoal(double.tryParse(v.replaceAll(',', '.')) ?? 0),
            )),
            panel(context, 'Moneda', SegmentedButton<String>(
              segments: const [ButtonSegment(value: '€', label: Text('€')), ButtonSegment(value: r'$', label: Text(r'$')), ButtonSegment(value: '£', label: Text('£')), ButtonSegment(value: 'R\$', label: Text('R\$'))],
              selected: {s.currency},
              onSelectionChanged: (v) => s.setCurrency(v.first),
            )),
            panel(context, 'Reflexión del mes', TextFormField(
              key: ValueKey('r${Store.key(s.month)}'),
              initialValue: s.reflections[Store.key(s.month)] ?? '',
              maxLines: 4,
              decoration: const InputDecoration(hintText: '¿Cuánto querías ahorrar, cuánto ahorraste y cómo puedes mejorar?'),
              onChanged: s.setReflection,
            )),
            panel(context, 'Seguridad', Column(children: [
              _tile(Icons.lock_rounded, s.hasPin ? 'Cambiar PIN' : 'Activar PIN', () => Navigator.push(context, MaterialPageRoute(builder: (_) => PinSetupPage(s))), sub: 'Se pide al abrir la app y al volver a ella'),
              if (s.hasPin) _tile(Icons.lock_open_rounded, 'Quitar PIN', () => s.setPin(null)),
            ])),
            panel(context, 'Automatización', Column(children: [
              _tile(Icons.repeat_rounded, 'Recurrentes (${s.rec.length})', () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringPage(s)))),
              _tile(Icons.category_rounded, 'Mis categorías (${s.custom.length})', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesPage(s)))),
            ])),
            panel(context, 'Tus datos', Column(children: [
              _tile(Icons.table_chart_rounded, 'Exportar CSV (copiar)', () => _copy(context, s.csv(), 'CSV copiado. Pégalo en una hoja de cálculo.')),
              _tile(Icons.backup_rounded, 'Copia de seguridad (copiar)', () => _copy(context, s.exportJson(), 'Copia lista. Guárdala en tus notas o en un correo.')),
              _tile(Icons.restore_rounded, 'Restaurar copia', () => _restore(context)),
            ])),
            panel(context, 'Topes por categoría', Column(children: [
              for (final k in allCats)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: groupColors[k.group].withAlpha(45), child: Icon(k.icon, color: groupColors[k.group])),
                  title: Text(k.name),
                  trailing: Text((s.budgets[k.name] ?? 0) > 0 ? f.format(s.budgets[k.name]) : 'Sin tope'),
                  onTap: () => _budget(context, k),
                ),
            ])),
          ]);
        },
      );
}
