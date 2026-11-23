import 'package:flutter/foundation.dart';
import 'package:meapps_ui/meapps_ui.dart';

class ChecklistItem {
  ChecklistItem(this.text, {this.done = false});
  final String text;
  bool done;
}

class MockNote {
  MockNote({
    required this.id,
    required this.title,
    this.body = '',
    this.checklist = const [],
    this.tag,
    this.pinned = false,
    this.tone = MeTone.plain,
    this.reminder,
  });

  final String id;
  final String title;
  final String body;
  final List<ChecklistItem> checklist;
  final String? tag;
  final bool pinned;
  final MeTone tone;
  final DateTime? reminder;
}

enum Repeat {
  never('Não repetir'),
  daily('Diário'),
  weekly('Semanal');

  const Repeat(this.label);
  final String label;
}

class MockReminder {
  MockReminder({
    required this.id,
    required this.title,
    required this.when,
    this.done = false,
    this.repeat = Repeat.never,
    this.noteId,
  });

  final String id;
  final String title;
  final DateTime when;
  bool done;
  final Repeat repeat;
  final String? noteId;
}

DateTime _at(int dayOffset, int hour, [int minute = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + dayOffset, hour, minute);
}

/// In-memory fake data for the mockups. Dates are relative to "now" so the
/// screens always look alive.
class MockStore extends ChangeNotifier {
  final notes = <MockNote>[
    MockNote(
      id: 'n1',
      title: 'Lista de compras',
      tag: 'Casa',
      pinned: true,
      tone: MeTone.tertiary,
      checklist: [
        ChecklistItem('Leite', done: true),
        ChecklistItem('Pão'),
        ChecklistItem('Ovos'),
        ChecklistItem('Café'),
        ChecklistItem('Fruta'),
      ],
    ),
    MockNote(
      id: 'n2',
      title: 'Reunião de projeto',
      body: 'Rever roadmap do primeiro trimestre, alinhar prioridades com a '
          'equipa e definir responsáveis por cada entrega.',
      tag: 'Trabalho',
      pinned: true,
      tone: MeTone.primary,
      reminder: _at(1, 10),
    ),
    MockNote(
      id: 'n3',
      title: 'Ideias para o fim de semana',
      body: 'Caminhada na serra, almoço com a família, ver o filme que ficou '
          'pendente.',
      tag: 'Pessoal',
    ),
    MockNote(
      id: 'n4',
      title: 'Receita de bolo de cenoura',
      body: '3 cenouras, 3 ovos, 1 chávena de óleo, 2 de açúcar, 2 de farinha. '
          'Forno a 180º durante 40 minutos.',
      tag: 'Casa',
      tone: MeTone.secondary,
    ),
    MockNote(
      id: 'n5',
      title: 'Livros para ler',
      tag: 'Pessoal',
      checklist: [
        ChecklistItem('Hábitos Atómicos'),
        ChecklistItem('O Nome da Rosa', done: true),
        ChecklistItem('Sapiens'),
      ],
    ),
    MockNote(
      id: 'n6',
      title: 'Consulta no dentista',
      body: 'Levar o cartão de utente e os exames anteriores.',
      tag: 'Pessoal',
      reminder: _at(3, 15, 30),
    ),
  ];

  final reminders = <MockReminder>[
    MockReminder(id: 'r1', title: 'Pagar a renda', when: _at(-1, 9)),
    MockReminder(id: 'r2', title: 'Tomar vitaminas', when: _at(0, 8), done: true, repeat: Repeat.daily),
    MockReminder(id: 'r3', title: 'Ligar à mãe', when: _at(0, 18, 30)),
    MockReminder(id: 'r4', title: 'Enviar relatório semanal', when: _at(0, 17)),
    MockReminder(id: 'r5', title: 'Reunião de projeto', when: _at(1, 10), noteId: 'n2'),
    MockReminder(id: 'r6', title: 'Regar as plantas', when: _at(2, 19), repeat: Repeat.weekly),
    MockReminder(id: 'r7', title: 'Consulta no dentista', when: _at(3, 15, 30), noteId: 'n6'),
    MockReminder(id: 'r8', title: 'Renovar seguro do carro', when: _at(9, 12)),
    MockReminder(id: 'r9', title: 'Aniversário da Ana', when: _at(5, 9)),
  ];

  MockNote? noteById(String? id) {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  List<MockReminder> remindersOn(DateTime day) =>
      reminders.where((r) => isSameDay(r.when, day)).toList()
        ..sort((a, b) => a.when.compareTo(b.when));

  void toggle(MockReminder r) {
    r.done = !r.done;
    notifyListeners();
  }

  void add(MockReminder r) {
    reminders.add(r);
    notifyListeners();
  }
}
