import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../app/appearance.dart';
import '../data/app_store.dart';
import 'appearance_sheet.dart';
import 'calendar_screen.dart';
import 'new_reminder_sheet.dart';
import 'note_editor_screen.dart';
import 'notes_screen.dart';
import 'reminders_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, required this.appearance});

  final AppStore store;
  final AppearanceController appearance;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  DateTime _day = dateOnly(DateTime.now());

  static const _titles = ['Agenda', 'Notas', 'Lembretes'];

  void _onFab() {
    if (_index == 1) {
      openNoteEditor(context, widget.store);
    } else {
      showReminderSheet(
        context,
        widget.store,
        initialDay: _index == 0 ? _day : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        builder: (context, _) => IndexedStack(
          index: _index,
          children: [
            CalendarScreen(
              store: widget.store,
              selected: _day,
              onSelected: (d) => setState(() => _day = d),
            ),
            NotesScreen(store: widget.store),
            RemindersScreen(store: widget.store),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFab,
        icon: Icon(
          _index == 1 ? Icons.edit_outlined : Icons.add_alert_outlined,
        ),
        label: Text(_index == 1 ? 'Nova nota' : 'Novo lembrete'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2),
            label: 'Notas',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Lembretes',
          ),
        ],
      ),
    );
  }
}
