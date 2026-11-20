import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const groupLabels = ['Supervivencia', 'Opcional', 'Cultura', 'Extras'];
const groupColors = [Color(0xFF00BFA5), Color(0xFFFF9100), Color(0xFF7C4DFF), Color(0xFFFF4081)];

class Cat {
  final String name;
  final int group, idx; // idx: icono de iconPalette (-1 = categoría base)
  final IconData icon;
  const Cat(this.name, this.group, this.icon, [this.idx = -1]);
}

const iconPalette = <IconData>[Icons.star_rounded, Icons.favorite_rounded, Icons.work_rounded, Icons.school_rounded, Icons.sports_soccer_rounded, Icons.local_pizza_rounded, Icons.beach_access_rounded, Icons.directions_car_rounded, Icons.brush_rounded, Icons.cake_rounded, Icons.hotel_rounded, Icons.pets_rounded];

const baseCats = <Cat>[
  Cat('Alquiler o hipoteca', 0, Icons.home_rounded),
  Cat('Luz y agua', 0, Icons.bolt_rounded),
  Cat('Gas', 0, Icons.local_fire_department_rounded),
  Cat('Internet y móvil', 0, Icons.wifi_rounded),
  Cat('Supermercado', 0, Icons.shopping_cart_rounded),
  Cat('Transporte', 0, Icons.directions_bus_rounded),
  Cat('Gasolina', 0, Icons.local_gas_station_rounded),
  Cat('Salud y farmacia', 0, Icons.medical_services_rounded),
  Cat('Seguros', 0, Icons.shield_rounded),
  Cat('Impuestos', 0, Icons.account_balance_rounded),
  Cat('Hijos y colegio', 0, Icons.child_care_rounded),
  Cat('Mascotas', 0, Icons.pets_rounded),
  Cat('Deudas y préstamos', 0, Icons.credit_card_rounded),
  Cat('Restaurantes', 1, Icons.restaurant_rounded),
  Cat('Café y snacks', 1, Icons.local_cafe_rounded),
  Cat('Ropa y calzado', 1, Icons.checkroom_rounded),
  Cat('Compras online', 1, Icons.shopping_bag_rounded),
  Cat('Viajes', 1, Icons.flight_rounded),
  Cat('Gimnasio y deporte', 1, Icons.fitness_center_rounded),
  Cat('Belleza', 1, Icons.spa_rounded),
  Cat('Regalos', 1, Icons.card_giftcard_rounded),
  Cat('Tecnología', 1, Icons.devices_rounded),
  Cat('Streaming', 1, Icons.live_tv_rounded),
  Cat('Suscripciones', 1, Icons.autorenew_rounded),
  Cat('Libros y cursos', 2, Icons.menu_book_rounded),
  Cat('Cine y teatro', 2, Icons.theaters_rounded),
  Cat('Música y conciertos', 2, Icons.music_note_rounded),
  Cat('Videojuegos', 2, Icons.sports_esports_rounded),
  Cat('Imprevistos', 3, Icons.warning_amber_rounded),
  Cat('Reparaciones', 3, Icons.build_rounded),
  Cat('Donaciones', 3, Icons.volunteer_activism_rounded),
  Cat('Otros', 3, Icons.more_horiz_rounded),
];

const services = <String, List<String>>{
  'Streaming': ['Netflix', 'Disney+', 'Max', 'Prime Video', 'Apple TV+', 'Paramount+', 'Movistar+', 'Spotify', 'Apple Music', 'YouTube Premium', 'Crunchyroll', 'DAZN', 'Audible'],
  'Suscripciones': ['iCloud', 'Google One', 'Microsoft 365', 'Prensa digital', 'App de pago'],
};

List<Cat> allCats = List.of(baseCats);
Cat catOf(String n) => allCats.firstWhere((c) => c.name == n, orElse: () => baseCats.last);

class Tx {
  final int id;
  final bool income, fixed;
  final double amount;
  final String cat, note;
  final DateTime date;
  Tx({required this.id, required this.income, required this.amount, required this.cat, required this.date, this.note = '', this.fixed = false});
  Map<String, dynamic> toJson() => {'id': id, 'i': income, 'a': amount, 'c': cat, 'd': date.toIso8601String(), 'n': note, 'f': fixed};
  factory Tx.fromJson(Map<String, dynamic> j) => Tx(id: j['id'], income: j['i'], amount: (j['a'] as num).toDouble(), cat: j['c'], date: DateTime.parse(j['d']), note: j['n'] ?? '', fixed: j['f'] ?? false);
}

/// Movimiento recurrente mensual. [last] = último mes generado ('yyyy-MM').
class Rec {
  final int id, day;
  final bool income;
  final double amount;
  final String cat, note;
  String last;
  Rec({required this.id, required this.income, required this.amount, required this.cat, required this.day, required this.last, this.note = ''});
  Map<String, dynamic> toJson() => {'id': id, 'i': income, 'a': amount, 'c': cat, 'n': note, 'd': day, 'l': last};
  factory Rec.fromJson(Map<String, dynamic> j) => Rec(id: j['id'], income: j['i'], amount: (j['a'] as num).toDouble(), cat: j['c'], note: j['n'] ?? '', day: j['d'], last: j['l']);
}

Map<String, double> _dm(Map? m) => {for (final e in (m ?? {}).entries) e.key as String: (e.value as num).toDouble()};

class Store extends ChangeNotifier {
  late SharedPreferences _p;
  List<Tx> txs = [];
  List<Rec> rec = [];
  List<Cat> custom = [];
  Map<String, double> goals = {}, budgets = {};
  Map<String, String> reflections = {};
  String currency = '€';
  String? _pin;
  bool locked = false;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  static String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  // ---------- PIN ----------
  bool get hasPin => _pin != null;
  String _h(String p) => sha256.convert(utf8.encode('kakeo:$p')).toString();
  bool checkPin(String p) => _pin == _h(p);
  void setPin(String? p) {
    _pin = p == null ? null : _h(p);
    if (_pin == null) { _p.remove('pin'); } else { _p.setString('pin', _pin!); }
    locked = false;
    notifyListeners();
  }
  void unlock() { locked = false; notifyListeners(); }
  void lockNow() { if (hasPin && !locked) { locked = true; notifyListeners(); } }

  // ---------- Persistencia ----------
  void _rebuild() => allCats = [...baseCats, ...custom];

  Map<String, dynamic> _data() => {
        'tx': txs.map((t) => t.toJson()).toList(),
        'rec': rec.map((r) => r.toJson()).toList(),
        'cats': custom.map((c) => {'n': c.name, 'g': c.group, 'i': c.idx}).toList(),
        'goals': goals, 'budgets': budgets, 'refl': reflections, 'cur': currency,
      };

  void _apply(Map j) {
    txs = [for (final t in j['tx'] ?? []) Tx.fromJson(Map<String, dynamic>.from(t))];
    rec = [for (final r in j['rec'] ?? []) Rec.fromJson(Map<String, dynamic>.from(r))];
    custom = [for (final c in j['cats'] ?? []) Cat(c['n'], c['g'], iconPalette[c['i']], c['i'])];
    goals = _dm(j['goals']);
    budgets = _dm(j['budgets']);
    reflections = Map<String, String>.from(j['refl'] ?? {});
    currency = j['cur'] ?? '€';
    _rebuild();
  }

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    _pin = _p.getString('pin');
    locked = _pin != null;
    final raw = _p.getString('kakeo');
    if (raw != null) { try { _apply(jsonDecode(raw)); } catch (_) {} }
    applyRecurring();
  }

  void _save({bool notify = true}) {
    _p.setString('kakeo', jsonEncode(_data()));
    if (notify) notifyListeners();
  }

  String exportJson() => jsonEncode(_data());
  void importJson(String raw) {
    final j = jsonDecode(raw);
    if (j is! Map || j['tx'] is! List) throw const FormatException('copia no válida');
    _apply(j);
    _save();
  }

  String csv() {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final l = [...txs]..sort((a, b) => a.date.compareTo(b.date));
    return [
      'fecha,tipo,categoria,importe,nota,fijo',
      for (final t in l) '${t.date.toIso8601String().substring(0, 10)},${t.income ? 'ingreso' : 'gasto'},${q(t.cat)},${t.amount.toStringAsFixed(2)},${q(t.note)},${t.fixed ? 'si' : 'no'}',
    ].join('\n');
  }

  // ---------- Recurrentes ----------
  void applyRecurring() {
    final now = DateTime.now();
    var changed = false;
    for (final r in rec) {
      final p = r.last.split('-');
      var cy = int.parse(p[0]), cm = int.parse(p[1]);
      while (true) {
        cm++;
        if (cm > 12) { cm = 1; cy++; }
        final dim = DateUtils.getDaysInMonth(cy, cm);
        final d = DateTime(cy, cm, r.day > dim ? dim : r.day);
        if (d.isAfter(now)) break;
        txs.add(Tx(id: DateTime.now().microsecondsSinceEpoch + txs.length, income: r.income, amount: r.amount, cat: r.cat, date: d, note: r.note, fixed: !r.income));
        r.last = '$cy-${cm.toString().padLeft(2, '0')}';
        changed = true;
      }
    }
    if (changed) _save();
  }
  void addRec(Rec r) { rec.add(r); _save(); }
  void removeRec(int id) { rec.removeWhere((r) => r.id == id); _save(); }

  // ---------- Categorías propias ----------
  void addCat(Cat c) { custom.add(c); _rebuild(); _save(); }
  void removeCat(String name) { custom.removeWhere((c) => c.name == name); _rebuild(); _save(); }

  // ---------- Movimientos ----------
  void shift(int n) { month = DateTime(month.year, month.month + n); notifyListeners(); }
  void add(Tx t) { txs.add(t); _save(); }
  void remove(int id) { txs.removeWhere((t) => t.id == id); _save(); }
  void setGoal(double v) { goals[key(month)] = v; _save(notify: false); }
  void setBudget(String c, double v) { budgets[c] = v; _save(); }
  void setCurrency(String c) { currency = c; _save(); }
  void setReflection(String v) { reflections[key(month)] = v; _save(notify: false); }

  List<Tx> get monthTx => txs.where((t) => t.date.year == month.year && t.date.month == month.month).toList()..sort((a, b) => b.date.compareTo(a.date));
  double _sum(Iterable<Tx> l) => l.fold(0.0, (a, t) => a + t.amount);
  double get income => _sum(monthTx.where((t) => t.income));
  double get spent => _sum(monthTx.where((t) => !t.income));
  double get fixedSpent => _sum(monthTx.where((t) => !t.income && t.fixed));
  double get goal => goals[key(month)] ?? 0;
  double get left => income - goal - spent;
  int get weeks => (DateUtils.getDaysInMonth(month.year, month.month) / 7).ceil();
  double get allowance => (income - goal - fixedSpent).clamp(0, double.infinity).toDouble() / weeks;
  List<double> get weekSpend {
    final w = List.filled(weeks, 0.0);
    for (final t in monthTx.where((t) => !t.income && !t.fixed)) {
      w[((t.date.day - 1) ~/ 7).clamp(0, weeks - 1)] += t.amount;
    }
    return w;
  }
  List<double> get byGroup => List.generate(4, (g) => _sum(monthTx.where((t) => !t.income && catOf(t.cat).group == g)));
  double spentIn(String c) => _sum(monthTx.where((t) => !t.income && t.cat == c));
  double total(DateTime m, bool inc) => _sum(txs.where((t) => t.income == inc && t.date.year == m.year && t.date.month == m.month));
}
