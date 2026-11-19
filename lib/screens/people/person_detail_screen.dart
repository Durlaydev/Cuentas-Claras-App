import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../providers/debts_provider.dart';
import '../../providers/people_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/debt_type_label.dart';
import '../../widgets/balance_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/money_text.dart';
import '../debts/debt_detail_screen.dart';
import '../debts/debt_form_screen.dart';

/// Detalle de una persona: sus datos, su saldo neto y la lista de sus
/// deudas, con búsqueda por texto y filtro por [DebtFilter].
class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final String personId;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  String _query = '';
  DebtFilter _filter = DebtFilter.all;

  /// Combina búsqueda + filtro de deudas de esta persona reutilizando
  /// `DebtsProvider.filtered` (que ya implementa la lógica de texto y de
  /// [DebtFilter]) y acotando el resultado a `widget.personId` con un
  /// `where` local. Se eligió esta estrategia en lugar de duplicar la
  /// lógica de `filtered` a mano sobre `debtsForPerson`, para no tener dos
  /// implementaciones del mismo criterio de búsqueda/filtro divergiendo
  /// con el tiempo.
  List<Debt> _visibleDebts(DebtsProvider debtsProvider, PeopleProvider peopleProvider) {
    return debtsProvider
        .filtered(
          query: _query,
          filter: _filter,
          personNameResolver: (personId) {
            final match = peopleProvider.people.where((p) => p.id == personId);
            return match.isEmpty ? '' : match.first.name;
          },
        )
        .where((debt) => debt.personId == widget.personId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final peopleProvider = context.watch<PeopleProvider>();
    final debtsProvider = context.watch<DebtsProvider>();

    final matches = peopleProvider.people.where((p) => p.id == widget.personId);
    final person = matches.isEmpty ? null : matches.first;

    if (person == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Persona')),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          message: 'Esta persona ya no existe.',
        ),
      );
    }

    final netBalance = peopleProvider.netBalanceForPerson(widget.personId);
    final debts = _visibleDebts(debtsProvider, peopleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(person.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (person.phone != null) Text(person.phone!),
                    if (person.note != null) Text(person.note!),
                  ],
                ),
                BalanceBadge(cents: netBalance),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar deuda',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: DebtFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filterLabel(filter)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: debts.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'No hay deudas que coincidan con la búsqueda.',
                  )
                : ListView.builder(
                    itemCount: debts.length,
                    itemBuilder: (context, index) {
                      final debt = debts[index];
                      return Dismissible(
                        key: ValueKey(debt.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Theme.of(context).colorScheme.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete_outline),
                        ),
                        onDismissed: (_) {
                          final messenger = ScaffoldMessenger.of(context);
                          final provider = context.read<DebtsProvider>();
                          // Cancela el recordatorio antes de eliminar: si no
                          // existía uno programado, es un no-op seguro.
                          _cancelReminderSilently(context, debt.id);
                          provider.deleteDebt(debt.id);
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Deuda eliminada'),
                              action: SnackBarAction(
                                label: 'Deshacer',
                                onPressed: () => provider.restoreLastDeletedDebt(),
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          title: Text(debt.description),
                          subtitle: Text(debt.type.label),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MoneyText(cents: debtsProvider.debtBalance(debt)),
                              if (debt.status == DebtStatus.paid)
                                const Text('Pagada', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DebtDetailScreen(debtId: debt.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agregar deuda',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DebtFormScreen(personId: widget.personId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _cancelReminderSilently(BuildContext context, String debtId) {
    try {
      context.read<NotificationService>().cancelReminder(debtId);
    } catch (_) {
      // Los recordatorios son un nice-to-have: si falla la cancelación
      // (por ejemplo, el servicio no está disponible en este árbol de
      // providers durante un test), se ignora en silencio.
    }
  }

  String _filterLabel(DebtFilter filter) {
    switch (filter) {
      case DebtFilter.all:
        return 'Todas';
      case DebtFilter.owedToMe:
        return 'Me deben';
      case DebtFilter.iOwe:
        return 'Debo';
      case DebtFilter.overdue:
        return 'Vencidas';
    }
  }
}
