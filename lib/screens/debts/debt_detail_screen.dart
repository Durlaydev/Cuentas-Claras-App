import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../providers/debts_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/debt_type_label.dart';
import '../../utils/money_formatter.dart';
import '../../utils/validators.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/money_text.dart';
import 'debt_form_screen.dart';

/// Detalle de una deuda: datos generales, saldo pendiente, historial de
/// pagos, y acciones para registrar un pago, marcarla como pagada o
/// editarla.
class DebtDetailScreen extends StatefulWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final String debtId;

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  Future<void> _showRegisterPaymentDialog(Debt debt) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime date = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Registrar pago'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Monto'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: validateAmountInput,
                    ),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Nota (opcional)'),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Fecha: ${_formatDate(date)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: date,
                          firstDate: DateTime(date.year - 5),
                          lastDate: DateTime(date.year + 5),
                        );
                        if (picked != null) {
                          setDialogState(() => date = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final amountCents = parseCentsFromInput(amountController.text);
                    final note = noteController.text.trim();
                    await context.read<DebtsProvider>().registerPayment(
                          debtId: debt.id,
                          amountCents: amountCents,
                          date: date,
                          note: note.isEmpty ? null : note,
                        );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markPaid(Debt debt) async {
    final notificationService = _readNotificationService();
    await context.read<DebtsProvider>().markPaid(debt.id);
    if (notificationService == null) return;
    try {
      await notificationService.cancelReminder(debt.id);
    } catch (_) {
      // Los recordatorios son un nice-to-have: se ignora en silencio si
      // falla la cancelación.
    }
  }

  NotificationService? _readNotificationService() {
    try {
      return context.read<NotificationService>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtsProvider = context.watch<DebtsProvider>();
    final matches = debtsProvider.debts.where((d) => d.id == widget.debtId);
    final debt = matches.isEmpty ? null : matches.first;

    if (debt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deuda')),
        body: const EmptyState(
          icon: Icons.receipt_long_outlined,
          message: 'Esta deuda ya no existe.',
        ),
      );
    }

    final balance = debtsProvider.debtBalance(debt);
    final payments = debtsProvider.paymentsForDebt(debt.id);
    final isPaid = debt.status == DebtStatus.paid;

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.description),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DebtFormScreen(personId: debt.personId, existingDebt: debt),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debt.type.label),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Monto: '),
                    MoneyText(cents: debt.amountCents),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Saldo pendiente: '),
                    MoneyText(cents: balance, colorByValue: true),
                  ],
                ),
                if (debt.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text('Vence: ${_formatDate(debt.dueDate!)}'),
                ],
                const SizedBox(height: 4),
                Text(isPaid ? 'Estado: Pagada' : 'Estado: Pendiente'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: isPaid ? null : () => _markPaid(debt),
                  child: const Text('Marcar como pagada'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: payments.isEmpty
                ? const EmptyState(
                    icon: Icons.payments_outlined,
                    message: 'Todavía no hay pagos registrados.',
                  )
                : ListView.builder(
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      return Dismissible(
                        key: ValueKey(payment.id),
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
                          provider.deletePayment(payment.id);
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Pago eliminado'),
                              action: SnackBarAction(
                                label: 'Deshacer',
                                onPressed: () => provider.restoreLastDeletedPayment(),
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          title: MoneyText(cents: payment.amountCents),
                          subtitle: Text(
                            payment.note == null
                                ? _formatDate(payment.date)
                                : '${_formatDate(payment.date)} · ${payment.note}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Registrar pago',
        onPressed: () => _showRegisterPaymentDialog(debt),
        child: const Icon(Icons.attach_money),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
