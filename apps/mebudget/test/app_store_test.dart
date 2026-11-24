import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';
import 'package:mebudget/data/app_store.dart';
import 'package:mebudget/data/category_icon.dart';
import 'package:mebudget/data/database.dart';
import 'package:mebudget/data/months.dart';
import 'package:mebudget/screens/entry_sheet.dart';
import 'package:mebudget/screens/summary_screen.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mebudget_test');
    file = File('${dir.path}/db.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppStore> open({bool seedDemo = false}) async {
    final store = AppStore(AppDatabase(NativeDatabase(file)));
    await store.init(seedDemo: seedDemo);
    return store;
  }

  const expense = EntryKind.expense;
  const income = EntryKind.income;
  const outrosDespesa = 'outros-despesa';
  const outrosReceita = 'outros-receita';

  var seq = 0;
  Entry entry(
    DateTime date,
    int cents, {
    EntryKind kind = expense,
    String? categoryId,
    String note = '',
  }) => Entry(
    id: 'e${seq++}',
    kind: kind,
    amountCents: cents,
    categoryId: categoryId ?? kind.otherCategoryId,
    date: date,
    note: note,
    createdAt: DateTime(2026, 1, 1).add(Duration(seconds: seq)),
  );

  Future<Category> addCategory(
    AppStore s,
    String id, {
    EntryKind kind = expense,
    int? budget,
  }) => s.saveCategory(
    Category(id: id, name: id, kind: kind, monthlyBudgetCents: budget),
  );

  group('init', () {
    test(
      'a brand new database without demo has only the two "Outros"',
      () async {
        final s = await open();
        expect(s.entries, isEmpty);
        expect(s.categories.map((c) => c.id).toSet(), {
          outrosDespesa,
          outrosReceita,
        });
        expect(
          s.categories.every((c) => c.isFixed && c.name == 'Outros'),
          isTrue,
        );
        await s.close();
      },
    );

    test('seeds demo data only on a brand new database', () async {
      final first = await open(seedDemo: true);
      final categories = first.categories.length;
      final entries = first.entries.length;
      expect(categories, greaterThan(2));
      expect(entries, greaterThan(10));
      expect(first.categoryById(outrosDespesa)?.isFixed, isTrue);
      expect(first.categoryById(outrosReceita)?.isFixed, isTrue);
      await first.deleteEntry(first.entries.first.id);

      await first.close();
      final second = await open(seedDemo: true);
      expect(second.categories.length, categories);
      expect(second.entries.length, entries - 1);
      await second.close();
    });

    test('no demo is seeded once the database has been used', () async {
      final first = await open();
      await first.close();
      final second = await open(seedDemo: true);
      expect(second.entries, isEmpty);
      await second.close();
    });

    test('demo covers this month and the previous one, with no future '
        'entries and Restauração over budget', () async {
      final s = await open(seedDemo: true);
      final now = DateTime.now();
      final month = monthOf(now);
      expect(s.entriesIn(month), isNotEmpty);
      expect(s.entriesIn(addMonths(month, -1)), isNotEmpty);
      expect(s.entries.every((e) => !e.date.isAfter(now)), isTrue);
      expect(s.totals(month).incomeCents, greaterThan(0));
      final rest = s
          .categoryTotals(month, expense)
          .firstWhere((t) => t.category.name == 'Restauração');
      expect(rest.isOverBudget, isTrue);
      expect(s.entries.every((e) => e.amountCents > 0), isTrue);
      await s.close();
    });
  });

  test('categories, movements and settings survive a restart', () async {
    final a = await open();
    await a.saveCategory(
      const Category(
        id: 'casa',
        name: '  Casa ',
        kind: expense,
        icon: CategoryIcon.home,
        tone: MeTone.tertiary,
        monthlyBudgetCents: 75000,
      ),
    );
    await a.saveEntry(
      Entry(
        id: 'x',
        kind: expense,
        amountCents: 65000,
        categoryId: 'casa',
        date: DateTime(2026, 11, 3, 18, 45),
        note: ' Renda ',
        createdAt: DateTime(2026, 11, 3, 18, 45, 12),
      ),
    );
    await a.setSetting('appearance.mode', 'dark');

    await a.close();
    final b = await open();
    final c = b.categoryById('casa')!;
    expect(c.name, 'Casa');
    expect(c.kind, expense);
    expect(c.icon, CategoryIcon.home);
    expect(c.tone, MeTone.tertiary);
    expect(c.monthlyBudgetCents, 75000);
    final e = b.entries.single;
    expect(e.amountCents, 65000);
    expect(e.categoryId, 'casa');
    expect(e.date, DateTime(2026, 11, 3));
    expect(e.note, 'Renda');
    expect(e.createdAt, DateTime(2026, 11, 3, 18, 45, 12));
    expect(b.settings['appearance.mode'], 'dark');
    await b.close();
  });

  group('month totals', () {
    test('only count movements inside the month', () async {
      final s = await open();
      await s.saveEntry(entry(DateTime(2026, 10, 31), 100));
      await s.saveEntry(entry(DateTime(2026, 11, 1), 200));
      await s.saveEntry(entry(DateTime(2026, 11, 30), 400));
      await s.saveEntry(entry(DateTime(2026, 12, 1), 800));
      await s.saveEntry(entry(DateTime(2025, 11, 15), 1600));

      final nov = s.totals(DateTime(2026, 11));
      expect(nov.expenseCents, 600);
      expect(s.totals(DateTime(2026, 10)).expenseCents, 100);
      expect(s.totals(DateTime(2026, 12)).expenseCents, 800);
      expect(s.totals(DateTime(2027)).isEmpty, isTrue);
      expect(s.entriesIn(DateTime(2026, 11)).map((e) => e.amountCents), [
        400,
        200,
      ]);
      await s.close();
    });

    test('keep incomes and expenses apart', () async {
      final s = await open();
      final nov = DateTime(2026, 11, 10);
      await s.saveEntry(entry(nov, 185000, kind: income));
      await s.saveEntry(entry(nov, 12000, kind: income));
      await s.saveEntry(entry(nov, 65000));
      await s.saveEntry(entry(nov, 4830));

      final t = s.totals(DateTime(2026, 11));
      expect(t.incomeCents, 197000);
      expect(t.expenseCents, 69830);
      expect(t.balanceCents, 127170);
      expect(t.isEmpty, isFalse);
      await s.close();
    });

    test('a negative balance when spending more than earning', () async {
      final s = await open();
      await s.saveEntry(entry(DateTime(2026, 11, 2), 1000, kind: income));
      await s.saveEntry(entry(DateTime(2026, 11, 2), 2550));
      expect(s.totals(DateTime(2026, 11)).balanceCents, -1550);
      await s.close();
    });
  });

  group('categoryTotals', () {
    test('sums per category, shares and budget overrun', () async {
      final s = await open();
      await addCategory(s, 'casa', budget: 75000);
      await addCategory(s, 'rest', budget: 15000);
      await addCategory(s, 'lazer', budget: 10000);
      await addCategory(s, 'saude');
      await addCategory(s, 'salario', kind: income);
      final d = DateTime(2026, 11, 5);
      await s.saveEntry(entry(d, 65000, categoryId: 'casa'));
      await s.saveEntry(entry(d, 10000, categoryId: 'rest'));
      await s.saveEntry(entry(d, 6470, categoryId: 'rest'));
      await s.saveEntry(entry(d, 8530, categoryId: 'saude'));
      await s.saveEntry(entry(d, 185000, kind: income, categoryId: 'salario'));
      // Other months never count.
      await s.saveEntry(
        entry(DateTime(2026, 10, 31), 99900, categoryId: 'rest'),
      );

      final totals = s.categoryTotals(DateTime(2026, 11), expense);
      expect(totals.map((t) => (t.category.id, t.cents)), [
        ('casa', 65000),
        ('rest', 16470),
        ('saude', 8530),
        // Budgeted but nothing spent yet: still listed.
        ('lazer', 0),
      ]);
      final casa = totals[0], rest = totals[1], saude = totals[2];
      expect(casa.share, closeTo(65000 / 90000, 1e-9));
      expect(totals.fold(0.0, (a, t) => a + t.share), closeTo(1, 1e-9));
      expect(casa.isOverBudget, isFalse);
      expect(casa.overBudgetCents, 0);
      expect(casa.budgetUsage, closeTo(65000 / 75000, 1e-9));
      expect(rest.isOverBudget, isTrue);
      expect(rest.overBudgetCents, 1470);
      expect(rest.budgetUsage, greaterThan(1));
      expect(saude.budgetCents, isNull);
      expect(saude.budgetUsage, isNull);
      expect(saude.overBudgetCents, 0);
      expect(totals[3].share, 0);

      final incomes = s.categoryTotals(DateTime(2026, 11), income);
      expect(incomes.single.category.id, 'salario');
      expect(incomes.single.share, 1);
      await s.close();
    });

    test('spending exactly the budget is not over it', () async {
      final s = await open();
      await addCategory(s, 'rest', budget: 15000);
      await s.saveEntry(
        entry(DateTime(2026, 11, 5), 15000, categoryId: 'rest'),
      );
      final t = s.categoryTotals(DateTime(2026, 11), expense).single;
      expect(t.isOverBudget, isFalse);
      expect(t.budgetUsage, 1);
      await s.close();
    });

    test(
      'ties keep the category order; empty month lists budgets only',
      () async {
        final s = await open();
        await addCategory(s, 'a');
        await addCategory(s, 'b', budget: 100);
        final d = DateTime(2026, 11, 5);
        await s.saveEntry(entry(d, 500, categoryId: 'b'));
        await s.saveEntry(entry(d, 500, categoryId: 'a'));
        expect(
          s
              .categoryTotals(DateTime(2026, 11), expense)
              .map((t) => t.category.id),
          ['a', 'b'],
        );
        expect(
          s
              .categoryTotals(DateTime(2026, 12), expense)
              .map((t) => t.category.id),
          ['b'],
        );
        await s.close();
      },
    );
  });

  test('entriesByDay groups newest day first with day sums', () async {
    final s = await open();
    await addCategory(s, 'casa');
    final d1 = DateTime(2026, 11, 3);
    final d2 = DateTime(2026, 11, 7);
    await s.saveEntry(entry(d1, 1000));
    await s.saveEntry(entry(d2, 250));
    await s.saveEntry(entry(d2, 5000, kind: income));
    await s.saveEntry(entry(d2, 700, categoryId: 'casa'));

    final groups = s.entriesByDay(DateTime(2026, 11));
    expect(groups.map((g) => g.day), [d2, d1]);
    expect(groups[0].entries, hasLength(3));
    // Most recently created first within a day.
    expect(groups[0].entries.first.categoryId, 'casa');
    expect(groups[0].incomeCents, 5000);
    expect(groups[0].expenseCents, 950);
    expect(groups[0].netCents, 4050);
    expect(groups[1].netCents, -1000);

    final filtered = s.entriesByDay(DateTime(2026, 11), categoryId: 'casa');
    expect(filtered.single.entries.single.amountCents, 700);
    expect(s.entriesByDay(DateTime(2026, 12)), isEmpty);
    await s.close();
  });

  test('categoriesUsedIn lists expenses first, in category order', () async {
    final s = await open();
    await addCategory(s, 'b');
    await addCategory(s, 'a');
    await addCategory(s, 'sal', kind: income);
    final d = DateTime(2026, 11, 5);
    await s.saveEntry(entry(d, 100, kind: income, categoryId: 'sal'));
    await s.saveEntry(entry(d, 100, categoryId: 'a'));
    await s.saveEntry(entry(d, 100));
    await s.saveEntry(entry(d, 100, categoryId: 'b'));
    expect(s.categoriesUsedIn(DateTime(2026, 11)).map((c) => c.id), [
      'b',
      'a',
      outrosDespesa,
      'sal',
    ]);
    expect(s.categoriesUsedIn(DateTime(2026, 12)), isEmpty);
    await s.close();
  });

  group('movements', () {
    test('editing replaces by id and stores the day only', () async {
      final s = await open();
      final e = await s.saveEntry(entry(DateTime(2026, 11, 3, 22, 10), 100));
      expect(e.date, DateTime(2026, 11, 3));
      await s.saveEntry(e.copyWith(amountCents: 300, note: 'café'));
      expect(s.entries.single.amountCents, 300);
      expect(s.entries.single.note, 'café');
      expect(s.entries.single.signedCents, -300);
      await s.close();
    });

    test('rejects zero amounts and mismatched categories', () async {
      final s = await open();
      await addCategory(s, 'sal', kind: income);
      expect(
        () => s.saveEntry(entry(DateTime(2026, 11, 3), 0)),
        throwsArgumentError,
      );
      expect(
        () => s.saveEntry(entry(DateTime(2026, 11, 3), 100, categoryId: 'sal')),
        throwsArgumentError,
      );
      expect(
        () => s.saveEntry(entry(DateTime(2026, 11, 3), 100, categoryId: '?')),
        throwsArgumentError,
      );
      expect(s.entries, isEmpty);
      await s.close();
    });

    test('delete returns the movement and restore undoes it', () async {
      final s = await open();
      await addCategory(s, 'casa');
      final e = await s.saveEntry(
        entry(DateTime(2026, 11, 3), 4830, categoryId: 'casa', note: 'Luz'),
      );
      expect(await s.deleteEntry('nope'), isNull);
      final removed = await s.deleteEntry(e.id);
      expect(removed?.note, 'Luz');
      expect(s.entries, isEmpty);
      expect(s.totals(DateTime(2026, 11)).isEmpty, isTrue);

      await s.restoreEntry(removed!);
      await s.close();
      final b = await open();
      expect(b.entries.single.id, e.id);
      expect(b.entries.single.categoryId, 'casa');
      expect(b.totals(DateTime(2026, 11)).expenseCents, 4830);
      await b.close();
    });

    test('restoring a movement whose category is gone uses "Outros"', () async {
      final s = await open();
      await addCategory(s, 'casa');
      final e = await s.saveEntry(
        entry(DateTime(2026, 11, 3), 100, categoryId: 'casa'),
      );
      final removed = await s.deleteEntry(e.id);
      await s.deleteCategory('casa');
      final restored = await s.restoreEntry(removed!);
      expect(restored.categoryId, outrosDespesa);
      await s.close();
    });
  });

  group('categories', () {
    test(
      'new ones go last in their kind; "Outros" always at the end',
      () async {
        final s = await open();
        await addCategory(s, 'a');
        await addCategory(s, 'b');
        await addCategory(s, 'sal', kind: income);
        expect(s.categoriesOf(expense).map((c) => c.id), [
          'a',
          'b',
          outrosDespesa,
        ]);
        expect(s.categoriesOf(income).map((c) => c.id), ['sal', outrosReceita]);
        expect(
          s.categoryById('b')!.position,
          greaterThan(s.categoryById('a')!.position),
        );
        await s.close();
      },
    );

    test('incomes never keep a budget; empty budgets are cleared', () async {
      final s = await open();
      final sal = await addCategory(s, 'sal', kind: income, budget: 1000);
      expect(sal.monthlyBudgetCents, isNull);
      final zero = await addCategory(s, 'z', budget: 0);
      expect(zero.monthlyBudgetCents, isNull);
      final casa = await addCategory(s, 'casa', budget: 500);
      final edited = await s.saveCategory(
        casa.copyWith(name: 'Lar', monthlyBudgetCents: null),
      );
      expect(edited.monthlyBudgetCents, isNull);
      expect(edited.name, 'Lar');
      expect(edited.position, casa.position);
      expect(casa.copyWith(name: 'x').monthlyBudgetCents, 500);
      await s.close();
    });

    test('rejects an empty name and a change of kind', () async {
      final s = await open();
      expect(
        () =>
            s.saveCategory(const Category(id: 'x', name: '  ', kind: expense)),
        throwsArgumentError,
      );
      await addCategory(s, 'x');
      expect(
        () => s.saveCategory(const Category(id: 'x', name: 'x', kind: income)),
        throwsArgumentError,
      );
      await s.close();
    });

    test('deleting moves its movements to "Outros" of the same kind', () async {
      final s = await open();
      await addCategory(s, 'rest', budget: 15000);
      await addCategory(s, 'sal', kind: income);
      final d = DateTime(2026, 11, 5);
      await s.saveEntry(entry(d, 1850, categoryId: 'rest'));
      await s.saveEntry(entry(DateTime(2026, 10, 5), 3200, categoryId: 'rest'));
      await s.saveEntry(entry(d, 185000, kind: income, categoryId: 'sal'));
      expect(s.entryCount('rest'), 2);

      final deleted = await s.deleteCategory('rest');
      expect(deleted?.category.id, 'rest');
      expect(deleted?.movedEntryIds, hasLength(2));
      expect(s.categoryById('rest'), isNull);
      expect(s.entryCount(outrosDespesa), 2);
      expect(s.entryCount('sal'), 1);
      // Totals do not change, only where the money is filed.
      expect(s.totals(DateTime(2026, 11)).expenseCents, 1850);

      await s.close();
      final b = await open();
      expect(b.categoryById('rest'), isNull);
      expect(b.entryCount(outrosDespesa), 2);
      await b.close();
    });

    test('income categories move to the income "Outros"', () async {
      final s = await open();
      await addCategory(s, 'sal', kind: income);
      await s.saveEntry(
        entry(DateTime(2026, 11, 5), 100, kind: income, categoryId: 'sal'),
      );
      await s.deleteCategory('sal');
      expect(s.entries.single.categoryId, outrosReceita);
      await s.close();
    });

    test('"Outros" cannot be deleted', () async {
      final s = await open();
      expect(await s.deleteCategory(outrosDespesa), isNull);
      expect(await s.deleteCategory(outrosReceita), isNull);
      expect(await s.deleteCategory('missing'), isNull);
      expect(s.categories, hasLength(2));
      await s.close();
    });

    test('restoring a deleted category brings its movements back', () async {
      final s = await open();
      await addCategory(s, 'rest', budget: 15000);
      await addCategory(s, 'casa');
      final d = DateTime(2026, 11, 5);
      final a = await s.saveEntry(entry(d, 100, categoryId: 'rest'));
      final b = await s.saveEntry(entry(d, 200, categoryId: 'rest'));
      final c = await s.saveEntry(entry(d, 400, categoryId: 'rest'));
      final already = await s.saveEntry(entry(d, 800));

      final deleted = await s.deleteCategory('rest');
      // Changed meanwhile: a deleted movement stays deleted and one filed
      // elsewhere stays there.
      await s.deleteEntry(b.id);
      await s.saveEntry(
        s.entries.firstWhere((e) => e.id == c.id).copyWith(categoryId: 'casa'),
      );
      await s.restoreCategory(deleted!);

      String categoryOf(Entry e) =>
          s.entries.firstWhere((x) => x.id == e.id).categoryId;
      expect(s.categoryById('rest')?.monthlyBudgetCents, 15000);
      expect(categoryOf(a), 'rest');
      expect(categoryOf(c), 'casa');
      expect(categoryOf(already), outrosDespesa);
      expect(s.entries, hasLength(3));

      await s.close();
      final reopened = await open();
      expect(reopened.entryCount('rest'), 1);
      expect(reopened.entryCount('casa'), 1);
      expect(reopened.entryCount(outrosDespesa), 1);
      await reopened.close();
    });

    test('unknown icon names fall back to the generic icon', () {
      expect(CategoryIcon.byName('home'), CategoryIcon.home);
      expect(CategoryIcon.byName('rocket'), CategoryIcon.other);
    });
  });

  test('settings persist and unchanged values are not rewritten', () async {
    final a = await open();
    await a.setSetting('appearance.mode', 'dark');
    await a.setSetting('appearance.mode', 'dark');
    await a.close();
    final b = await open();
    expect(b.settings, {'appearance.mode': 'dark'});
    await b.close();
  });

  group('months', () {
    test('helpers cross year boundaries', () {
      expect(monthOf(DateTime(2026, 11, 24, 15)), DateTime(2026, 11));
      expect(addMonths(DateTime(2026, 12), 1), DateTime(2027));
      expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
      expect(
        isSameMonth(DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
        isTrue,
      );
      expect(isSameMonth(DateTime(2026, 11), DateTime(2025, 11)), isFalse);
      expect(formatMonth(DateTime(2026, 11)), 'novembro 2026');
      expect(formatMonth(DateTime(2027, 3)), 'março 2027');
    });

    test('day keys round-trip', () {
      expect(dayKey(DateTime(2026, 11, 3, 23, 59)), 20261103);
      expect(fromDayKey(20261103), DateTime(2026, 11, 3));
      expect(fromDayKey(dayKey(DateTime(2028, 2, 29))), DateTime(2028, 2, 29));
    });

    test('new movements default to a day of the month on screen', () {
      final now = DateTime(2026, 11, 24, 10);
      expect(
        defaultEntryDate(DateTime(2026, 11), now: now),
        DateTime(2026, 11, 24),
      );
      expect(
        defaultEntryDate(DateTime(2026, 10), now: now),
        DateTime(2026, 10, 31),
      );
      expect(
        defaultEntryDate(DateTime(2026, 2), now: now),
        DateTime(2026, 2, 28),
      );
      expect(
        defaultEntryDate(DateTime(2027, 1), now: now),
        DateTime(2027, 1, 1),
      );
    });
  });

  test('formatShare rounds and flags tiny shares', () {
    expect(formatShare(0), '0%');
    expect(formatShare(0.001), '<1%');
    expect(formatShare(0.354), '35%');
    expect(formatShare(1), '100%');
  });

  test('newId never repeats', () {
    final ids = {for (var i = 0; i < 1000; i++) newId('e')};
    expect(ids, hasLength(1000));
  });
}
