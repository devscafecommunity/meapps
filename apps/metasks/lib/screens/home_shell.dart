import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import 'lists_screen.dart';
import 'search_results.dart';
import 'task_sheet.dart';
import 'today_screen.dart';
import 'upcoming_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, required this.appearance});

  final AppStore store;
  final AppearanceController appearance;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _searching = false;
  final _query = TextEditingController();

  static const _titles = ['Hoje', 'Próximas', 'Listas'];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// New tasks default to the day the current tab is about.
  void _onFab() {
    final today = dateOnly(DateTime.now());
    showTaskSheet(
      context,
      widget.store,
      initialDue: switch (_index) {
        0 => today,
        1 => DateTime(today.year, today.month, today.day + 1),
        _ => null,
      },
    );
  }

  void _closeSearch() => setState(() {
    _searching = false;
    _query.clear();
  });

  PreferredSizeWidget _appBar() {
    if (!_searching) {
      return AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Pesquisar',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true),
          ),
          IconButton(
            tooltip: 'Aparência',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => showAppearanceSheet(context, widget.appearance),
          ),
          const SizedBox(width: 4),
        ],
      );
    }
    return AppBar(
      leading: IconButton(
        tooltip: 'Fechar pesquisa',
        icon: const Icon(Icons.arrow_back),
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _query,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Pesquisar tarefas',
          filled: false,
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_query.text.isNotEmpty)
          IconButton(
            tooltip: 'Limpar',
            icon: const Icon(Icons.close),
            onPressed: () => setState(_query.clear),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: Scaffold(
        appBar: _appBar(),
        body: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => _searching
              ? SearchResults(store: widget.store, query: _query.text)
              : IndexedStack(
                  index: _index,
                  children: [
                    TodayScreen(store: widget.store),
                    UpcomingScreen(store: widget.store),
                    ListsScreen(store: widget.store),
                  ],
                ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _onFab,
          icon: const Icon(Icons.add_task),
          label: const Text('Nova tarefa'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() {
            _index = i;
            _searching = false;
            _query.clear();
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Hoje',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: 'Próximas',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Listas',
            ),
          ],
        ),
      ),
    );
  }
}
