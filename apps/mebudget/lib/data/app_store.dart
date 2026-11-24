import 'dart:math' show max;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show ChangeNotifier, immutable;
import 'package:meapps_ui/meapps_ui.dart';

import 'category_icon.dart';
import 'database.dart';
import 'months.dart';

/// Whether a movement takes money out (despesa) or brings it in (receita).
enum EntryKind {
  expense('Despesa', 'Despesas'),
  income('Receita', 'Receitas');

  const EntryKind(this.label, this.plural);
  final String label;
  final String plural;

  /// Id of the fixed "Outros" category of this kind.
  String get otherCategoryId => switch (this) {
    expense => 'outros-despesa',
    income => 'outros-receita',
  };
}

const _unset = Object();

@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.icon = CategoryIcon.other,
    this.tone = MeTone.plain,
    this.monthlyBudgetCents,
    this.position = 0,
  });

  final String id;
  final String name;
  final EntryKind kind;
  final CategoryIcon icon;
  final MeTone tone;

  /// Expenses only; null when the category has no monthly budget.
  final int? monthlyBudgetCents;
  final int position;

  /// The "Outros" category of its kind: it can be edited but never deleted,
  /// and receives the movements of deleted categories.
  bool get isFixed => id == kind.otherCategoryId;

  /// [monthlyBudgetCents] accepts `null` to clear it; omit it to keep it.
  /// The kind never changes: movements depend on it.
  Category copyWith({
    String? name,
    CategoryIcon? icon,
    MeTone? tone,
    Object? monthlyBudgetCents = _unset,
    int? position,
  }) => Category(
    id: id,
    name: name ?? this.name,
    kind: kind,
    icon: icon ?? this.icon,
    tone: tone ?? this.tone,
    monthlyBudgetCents: identical(monthlyBudgetCents, _unset)
        ? this.monthlyBudgetCents
        : monthlyBudgetCents as int?,
    position: position ?? this.position,
  );
}

/// A movement: money spent or received on a given day.
@immutable
class Entry {
  const Entry({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.categoryId,
    required this.date,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final EntryKind kind;

  /// Always positive; [kind] gives the direction.
  final int amountCents;
  final String categoryId;

  /// Day only (midnight).
  final DateTime date;
  final String note;
  final DateTime createdAt;

  /// Negative for expenses, positive for incomes.
  int get signedCents => kind == EntryKind.expense ? -amountCents : amountCents;

  Entry copyWith({
    EntryKind? kind,
    int? amountCents,
    String? categoryId,
    DateTime? date,
    String? note,
  }) => Entry(
    id: id,
    kind: kind ?? this.kind,
    amountCents: amountCents ?? this.amountCents,
    categoryId: categoryId ?? this.categoryId,
    date: date ?? this.date,
    note: note ?? this.note,
    createdAt: createdAt,
  );
}

/// Income, expenses and balance of one month.
@immutable
class MonthTotals {
  const MonthTotals({required this.incomeCents, required this.expenseCents});

  final int incomeCents;
  final int expenseCents;

  int get balanceCents => incomeCents - expenseCents;
  bool get isEmpty => incomeCents == 0 && expenseCents == 0;
}

/// What one category added up to in a month.
@immutable
class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.cents,
    required this.share,
  });

  final Category category;
  final int cents;

  /// Fraction (0..1) of every amount of the same kind that month.
  final double share;

  int? get budgetCents => category.monthlyBudgetCents;

  /// Spent / budget (can exceed 1), or null without a budget.
  double? get budgetUsage {
    final budget = budgetCents;
    return budget == null ? null : cents / budget;
  }

  /// How much was spent above the budget; 0 within it or without one.
  int get overBudgetCents {
    final budget = budgetCents;
    return budget == null ? 0 : max(0, cents - budget);
  }

  bool get isOverBudget => overBudgetCents > 0;
}

/// The movements of one day, newest first, with the day's sums.
@immutable
class DayGroup {
  const DayGroup({
    required this.day,
    required this.entries,
    required this.incomeCents,
    required this.expenseCents,
  });

  final DateTime day;
  final List<Entry> entries;
  final int incomeCents;
  final int expenseCents;

  int get netCents => incomeCents - expenseCents;
}

/// What [AppStore.deleteCategory] removed, so it can be put back.
typedef DeletedCategory = ({Category category, List<String> movedEntryIds});

var _idSeq = 0;

String newId(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch}_${_idSeq++}';

// --- Demo seed (first launch only) -------------------------------------

Category _fixedCategory(EntryKind kind, {int position = 99}) => Category(
  id: kind.otherCategoryId,
  name: 'Outros',
  kind: kind,
  position: position,
);

List<Category> _demoCategories() {
  const e = EntryKind.expense;
  const i = EntryKind.income;
  return [
    const Category(
      id: 'c_casa',
      name: 'Casa',
      kind: e,
      icon: CategoryIcon.home,
      tone: MeTone.primary,
      monthlyBudgetCents: 75000,
    ),
    const Category(
      id: 'c_super',
      name: 'Supermercado',
      kind: e,
      icon: CategoryIcon.groceries,
      tone: MeTone.tertiary,
      monthlyBudgetCents: 35000,
      position: 1,
    ),
    const Category(
      id: 'c_transportes',
      name: 'Transportes',
      kind: e,
      icon: CategoryIcon.transport,
      tone: MeTone.secondary,
      monthlyBudgetCents: 12000,
      position: 2,
    ),
    const Category(
      id: 'c_restauracao',
      name: 'Restauração',
      kind: e,
      icon: CategoryIcon.restaurant,
      tone: MeTone.tertiary,
      monthlyBudgetCents: 15000,
      position: 3,
    ),
    const Category(
      id: 'c_saude',
      name: 'Saúde',
      kind: e,
      icon: CategoryIcon.health,
      position: 4,
    ),
    const Category(
      id: 'c_lazer',
      name: 'Lazer',
      kind: e,
      icon: CategoryIcon.leisure,
      tone: MeTone.secondary,
      monthlyBudgetCents: 10000,
      position: 5,
    ),
    _fixedCategory(e, position: 6),
    const Category(
      id: 'c_salario',
      name: 'Salário',
      kind: i,
      icon: CategoryIcon.salary,
      tone: MeTone.primary,
    ),
    const Category(
      id: 'c_extras',
      name: 'Extras',
      kind: i,
      icon: CategoryIcon.extra,
      tone: MeTone.tertiary,
      position: 1,
    ),
    _fixedCategory(i, position: 2),
  ];
}

/// Day [day] of the month [monthOffset] months from now, clamped to the
/// month's length and, in the current month, to today (no future entries).
DateTime _demoDay(int monthOffset, int day) {
  final n = DateTime.now();
  final last = DateTime(n.year, n.month + monthOffset + 1, 0).day;
  var d = day > last ? last : day;
  if (monthOffset == 0 && d > n.day) d = n.day;
  return DateTime(n.year, n.month + monthOffset, d);
}

/// Dates are relative to "now" so the demo data always looks alive: the
/// current month (with Restauração over budget) and the previous one.
List<Entry> _demoEntries() {
  var seq = 0;
  Entry entry(
    int monthOffset,
    int day,
    String categoryId,
    int cents,
    String note, {
    EntryKind kind = EntryKind.expense,
  }) {
    final date = _demoDay(monthOffset, day);
    return Entry(
      id: 'e${seq++}',
      kind: kind,
      amountCents: cents,
      categoryId: categoryId,
      date: date,
      note: note,
      createdAt: date.add(Duration(hours: 9, minutes: seq)),
    );
  }

  const income = EntryKind.income;
  return [
    // Current month.
    entry(0, 1, 'c_salario', 185000, 'Ordenado', kind: income),
    entry(0, 1, 'c_casa', 65000, 'Renda'),
    entry(0, 2, 'c_super', 6240, 'Compras da semana'),
    entry(0, 3, 'c_transportes', 4000, 'Passe mensal'),
    entry(0, 4, 'c_restauracao', 1850, 'Almoço'),
    entry(0, 6, 'c_saude', 1490, 'Farmácia'),
    entry(0, 7, 'outros-despesa', 999, 'Assinatura de música'),
    entry(0, 8, 'c_casa', 4830, 'Eletricidade'),
    entry(0, 9, 'c_super', 3875, 'Mercado'),
    entry(0, 10, 'c_restauracao', 3200, 'Jantar com amigos'),
    entry(0, 11, 'c_lazer', 1500, 'Cinema'),
    entry(0, 12, 'c_transportes', 5500, 'Gasolina'),
    entry(0, 14, 'c_restauracao', 4500, 'Aniversário'),
    entry(0, 15, 'c_extras', 12000, 'Venda online', kind: income),
    entry(0, 16, 'c_super', 9120, 'Compras da semana'),
    entry(0, 18, 'c_restauracao', 2740, 'Pizzaria'),
    entry(0, 20, 'c_restauracao', 4180, 'Sushi'),
    // Previous month.
    entry(-1, 1, 'c_salario', 185000, 'Ordenado', kind: income),
    entry(-1, 1, 'c_casa', 65000, 'Renda'),
    entry(-1, 2, 'c_transportes', 4000, 'Passe mensal'),
    entry(-1, 3, 'c_super', 8430, 'Compras da semana'),
    entry(-1, 6, 'c_restauracao', 2250, 'Almoço'),
    entry(-1, 9, 'c_casa', 5210, 'Eletricidade'),
    entry(-1, 10, 'c_super', 7215, 'Mercado'),
    entry(-1, 12, 'c_casa', 2890, 'Água'),
    entry(-1, 13, 'c_restauracao', 3800, 'Jantar fora'),
    entry(-1, 15, 'c_transportes', 6020, 'Gasolina'),
    entry(-1, 17, 'c_super', 9960, 'Compras da semana'),
    entry(-1, 20, 'c_saude', 3500, 'Consulta'),
    entry(-1, 21, 'c_lazer', 2400, 'Concerto'),
    entry(-1, 22, 'c_extras', 25000, 'Trabalho extra', kind: income),
    entry(-1, 24, 'c_super', 6380, 'Mercado'),
    entry(-1, 27, 'c_restauracao', 1990, 'Café e bolos'),
    entry(-1, 28, 'c_lazer', 1200, 'Livro'),
  ];
}

// --- Store -------------------------------------------------------------

/// Single source of truth for the UI. Keeps the data in memory for
/// synchronous reads and writes every change through to SQLite (Drift).
/// Every sum shown on screen is computed here.
class AppStore extends ChangeNotifier {
  AppStore(this._db);

  final AppDatabase _db;
  List<Category> categories = [];
  List<Entry> entries = [];
  Map<String, String> settings = {};

  /// Loads from disk; seeds demo data when the database is brand new. The
  /// fixed "Outros" categories are created whenever they are missing.
  Future<void> init({bool seedDemo = true}) async {
    if (seedDemo &&
        await _db.select(_db.categories).get().then((r) => r.isEmpty)) {
      await _db.transaction(() async {
        for (final c in _demoCategories()) {
          await _writeCategory(c);
        }
        for (final e in _demoEntries()) {
          await _writeEntry(e);
        }
      });
    }
    await _load();
    for (final kind in EntryKind.values) {
      if (categoryById(kind.otherCategoryId) == null) {
        final c = _fixedCategory(kind, position: _nextPosition(kind));
        categories.add(c);
        await _writeCategory(c);
      }
    }
    notifyListeners();
  }

  Future<void> _load() async {
    categories = [
      for (final row in await _db.select(_db.categories).get())
        Category(
          id: row.id,
          name: row.name,
          kind: EntryKind.values[row.kind],
          icon: CategoryIcon.byName(row.icon),
          tone: MeTone.values[row.tone],
          monthlyBudgetCents: row.budgetCents,
          position: row.position,
        ),
    ];
    entries = [
      for (final row in await _db.select(_db.entries).get())
        Entry(
          id: row.id,
          kind: EntryKind.values[row.kind],
          amountCents: row.amountCents,
          categoryId: row.categoryId,
          date: fromDayKey(row.day),
          note: row.note,
          createdAt: row.createdAt,
        ),
    ];
    settings = {
      for (final row in await _db.select(_db.settings).get())
        row.key: row.value,
    };
  }

  Future<void> _writeCategory(Category c) => _db
      .into(_db.categories)
      .insertOnConflictUpdate(
        CategoriesCompanion(
          id: Value(c.id),
          name: Value(c.name),
          kind: Value(c.kind.index),
          icon: Value(c.icon.name),
          tone: Value(c.tone.index),
          budgetCents: Value(c.monthlyBudgetCents),
          position: Value(c.position),
        ),
      );

  Future<void> _writeEntry(Entry e) => _db
      .into(_db.entries)
      .insertOnConflictUpdate(
        EntriesCompanion(
          id: Value(e.id),
          kind: Value(e.kind.index),
          amountCents: Value(e.amountCents),
          categoryId: Value(e.categoryId),
          day: Value(dayKey(e.date)),
          note: Value(e.note),
          createdAt: Value(e.createdAt),
        ),
      );

  Future<void> close() => _db.close();

  // --- Queries ---------------------------------------------------------

  Category? categoryById(String? id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Categories of [kind] in their order, with "Outros" always last.
  List<Category> categoriesOf(EntryKind kind) =>
      categories.where((c) => c.kind == kind).toList()..sort((a, b) {
        if (a.isFixed != b.isFixed) return a.isFixed ? 1 : -1;
        return a.position.compareTo(b.position);
      });

  int _nextPosition(EntryKind kind) => categories
      .where((c) => c.kind == kind && !c.isFixed)
      .fold(0, (p, c) => max(p, c.position + 1));

  /// Movements of [month] (optionally of one category), newest day first and,
  /// within a day, most recently created first.
  List<Entry> entriesIn(DateTime month, {String? categoryId}) =>
      entries
          .where(
            (e) =>
                isSameMonth(e.date, month) &&
                (categoryId == null || e.categoryId == categoryId),
          )
          .toList()
        ..sort((a, b) {
          final byDay = b.date.compareTo(a.date);
          return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
        });

  /// [entriesIn] grouped by day, each group with its income/expense sums.
  List<DayGroup> entriesByDay(DateTime month, {String? categoryId}) {
    final groups = <DayGroup>[];
    var day = <Entry>[];
    void flush() {
      if (day.isEmpty) return;
      final t = _sum(day);
      groups.add(
        DayGroup(
          day: day.first.date,
          entries: day,
          incomeCents: t.incomeCents,
          expenseCents: t.expenseCents,
        ),
      );
      day = [];
    }

    for (final e in entriesIn(month, categoryId: categoryId)) {
      if (day.isNotEmpty && !isSameDay(day.first.date, e.date)) flush();
      day.add(e);
    }
    flush();
    return groups;
  }

  MonthTotals _sum(Iterable<Entry> list) {
    var income = 0;
    var expense = 0;
    for (final e in list) {
      if (e.kind == EntryKind.income) {
        income += e.amountCents;
      } else {
        expense += e.amountCents;
      }
    }
    return MonthTotals(incomeCents: income, expenseCents: expense);
  }

  MonthTotals totals(DateTime month) => _sum(entriesIn(month));

  /// Sums per category of [kind] in [month], largest first. Expense
  /// categories with a budget are listed even when nothing was spent yet.
  List<CategoryTotal> categoryTotals(DateTime month, EntryKind kind) {
    final sums = <String, int>{};
    for (final e in entriesIn(month)) {
      if (e.kind == kind) {
        sums[e.categoryId] = (sums[e.categoryId] ?? 0) + e.amountCents;
      }
    }
    final total = sums.values.fold(0, (a, b) => a + b);
    final cats = categoriesOf(kind);
    final result = [
      for (final c in cats)
        if ((sums[c.id] ?? 0) > 0 || c.monthlyBudgetCents != null)
          CategoryTotal(
            category: c,
            cents: sums[c.id] ?? 0,
            share: total == 0 ? 0 : (sums[c.id] ?? 0) / total,
          ),
    ];
    // Stable on equal sums: keeps the category order.
    final order = {for (var i = 0; i < cats.length; i++) cats[i].id: i};
    result.sort((a, b) {
      final byCents = b.cents.compareTo(a.cents);
      return byCents != 0
          ? byCents
          : order[a.category.id]!.compareTo(order[b.category.id]!);
    });
    return result;
  }

  /// Categories with at least one movement in [month], expenses first.
  List<Category> categoriesUsedIn(DateTime month) {
    final used = {for (final e in entriesIn(month)) e.categoryId};
    return [
      for (final kind in EntryKind.values)
        ...categoriesOf(kind).where((c) => used.contains(c.id)),
    ];
  }

  /// Movements of a category across every month.
  int entryCount(String categoryId) =>
      entries.where((e) => e.categoryId == categoryId).length;

  // --- Movements -------------------------------------------------------

  /// Inserts or replaces a movement (matched by id). The amount must be
  /// positive and the category must exist with the same kind.
  Future<Entry> saveEntry(Entry e) async {
    if (e.amountCents <= 0) {
      throw ArgumentError.value(e.amountCents, 'amountCents', 'must be > 0');
    }
    final category = categoryById(e.categoryId);
    if (category == null || category.kind != e.kind) {
      throw ArgumentError.value(e.categoryId, 'categoryId', 'wrong category');
    }
    final entry = e.copyWith(date: dateOnly(e.date), note: e.note.trim());
    final i = entries.indexWhere((x) => x.id == entry.id);
    if (i >= 0) {
      entries[i] = entry;
    } else {
      entries.add(entry);
    }
    notifyListeners();
    await _writeEntry(entry);
    return entry;
  }

  /// Returns the removed movement so the UI can offer "undo" through
  /// [restoreEntry].
  Future<Entry?> deleteEntry(String id) async {
    final i = entries.indexWhere((e) => e.id == id);
    if (i < 0) return null;
    final removed = entries.removeAt(i);
    notifyListeners();
    await (_db.delete(_db.entries)..where((t) => t.id.equals(id))).go();
    return removed;
  }

  /// Puts a deleted movement back. If its category is gone meanwhile it goes
  /// to "Outros".
  Future<Entry> restoreEntry(Entry e) {
    final category = categoryById(e.categoryId);
    return saveEntry(
      category == null || category.kind != e.kind
          ? e.copyWith(categoryId: e.kind.otherCategoryId)
          : e,
    );
  }

  // --- Categories ------------------------------------------------------

  /// Inserts or replaces a category (matched by id). New categories go to
  /// the end of their kind. Income categories never keep a budget.
  Future<Category> saveCategory(Category c) async {
    final name = c.name.trim();
    if (name.isEmpty) throw ArgumentError.value(c.name, 'name', 'is empty');
    final budget = c.monthlyBudgetCents;
    final i = categories.indexWhere((x) => x.id == c.id);
    if (i >= 0 && categories[i].kind != c.kind) {
      throw ArgumentError.value(c.kind, 'kind', 'cannot change');
    }
    final category = c.copyWith(
      name: name,
      monthlyBudgetCents: c.kind == EntryKind.expense && (budget ?? 0) > 0
          ? budget
          : null,
      position: i >= 0 || c.isFixed ? c.position : _nextPosition(c.kind),
    );
    if (i >= 0) {
      categories[i] = category;
    } else {
      categories.add(category);
    }
    notifyListeners();
    await _writeCategory(category);
    return category;
  }

  /// Deletes a category and moves its movements to "Outros" of the same
  /// kind. "Outros" itself cannot be deleted (returns null). Returns what
  /// changed so the UI can offer "undo" through [restoreCategory].
  Future<DeletedCategory?> deleteCategory(String id) async {
    final category = categoryById(id);
    if (category == null || category.isFixed) return null;
    final otherId = category.kind.otherCategoryId;
    final moved = <String>[];
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].categoryId == id) {
        entries[i] = entries[i].copyWith(categoryId: otherId);
        moved.add(entries[i].id);
      }
    }
    categories.removeWhere((c) => c.id == id);
    notifyListeners();
    await _db.transaction(() async {
      await (_db.update(_db.entries)..where((t) => t.categoryId.equals(id)))
          .write(EntriesCompanion(categoryId: Value(otherId)));
      await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
    });
    return (category: category, movedEntryIds: moved);
  }

  /// Brings a deleted category back with the movements that were moved to
  /// "Outros" (unless they were edited or deleted since).
  Future<void> restoreCategory(DeletedCategory deleted) async {
    final c = deleted.category;
    final otherId = c.kind.otherCategoryId;
    final ids = deleted.movedEntryIds.toSet();
    final back = <String>[];
    categories.add(c);
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (ids.contains(e.id) && e.categoryId == otherId) {
        entries[i] = e.copyWith(categoryId: c.id);
        back.add(e.id);
      }
    }
    notifyListeners();
    await _db.transaction(() async {
      await _writeCategory(c);
      await (_db.update(_db.entries)..where((t) => t.id.isIn(back))).write(
        EntriesCompanion(categoryId: Value(c.id)),
      );
    });
  }

  // --- Settings --------------------------------------------------------

  Future<void> setSetting(String key, String value) async {
    if (settings[key] == value) return;
    settings[key] = value;
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(SettingRow(key: key, value: value));
  }
}
