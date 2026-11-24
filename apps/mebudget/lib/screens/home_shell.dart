import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import 'categories_screen.dart';
import 'category_sheet.dart';
import 'entries_screen.dart';
import 'entry_sheet.dart';
import 'summary_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, required this.appearance});

  final AppStore store;
  final AppearanceController appearance;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Shared by Resumo and Movimentos.
  DateTime _month = monthOf(DateTime.now());

  static const _titles = ['Resumo', 'Movimentos', 'Categorias'];

  Future<void> _onFab() async {
    if (_index == 2) {
      await showCategorySheet(context, widget.store);
      return;
    }
    final saved = await showEntrySheet(
      context,
      widget.store,
      initialDate: defaultEntryDate(_month),
    );
    // Follow the new movement if it was dated in another month.
    if (saved != null && mounted && !isSameMonth(saved.date, _month)) {
      setState(() => _month = monthOf(saved.date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = monthOf(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Aparência',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => showAppearanceSheet(context, widget.appearance),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => Column(
          children: [
            if (_index < 2)
              Padding(
                // Lines the title up with the cards below.
                padding: const EdgeInsets.symmetric(horizontal: MeSpacing.md),
                child: MeMonthHeader(
                  month: _month,
                  onChanged: (m) => setState(() => _month = m),
                  todayLabel: 'Este mês',
                  onToday: isSameMonth(_month, current)
                      ? null
                      : () => setState(() => _month = current),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  SummaryScreen(store: widget.store, month: _month),
                  EntriesScreen(store: widget.store, month: _month),
                  CategoriesScreen(store: widget.store),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFab,
        icon: const Icon(Icons.add),
        label: Text(_index == 2 ? 'Nova categoria' : 'Novo movimento'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Resumo',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movimentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categorias',
          ),
        ],
      ),
    );
  }
}
