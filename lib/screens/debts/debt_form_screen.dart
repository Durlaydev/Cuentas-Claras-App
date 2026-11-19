import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../providers/debts_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/debt_type_label.dart';
import '../../utils/money_formatter.dart';
import '../../utils/validators.dart';

/// Formulario para crear o editar una deuda.
///
/// Si [existingDebt] es `null`, crea una deuda nueva (`addDebt`); si se
/// provee, edita esa deuda existente (`updateDebt`), precargando sus
/// valores en el formulario.
class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({super.key, required this.personId, this.existingDebt});

  final String personId;
  final Debt? existingDebt;

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DebtType _type;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  DateTime? _dueDate;

  bool get _isEditing => widget.existingDebt != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingDebt;
    _type = existing?.type ?? DebtType.owedToMe;
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : (existing.amountCents / 100).toStringAsFixed(2),
    );
    _dueDate = existing?.dueDate;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amountCents = parseCentsFromInput(_amountController.text);
    final description = _descriptionController.text.trim();
    final provider = context.read<DebtsProvider>();
    final notificationService = _readNotificationService();

    String debtId;
    if (_isEditing) {
      final existing = widget.existingDebt!;
      final updated = existing.copyWith(
        type: _type,
        description: description,
        amountCents: amountCents,
        dueDate: _dueDate,
      );
      await provider.updateDebt(updated);
      debtId = updated.id;
    } else {
      await provider.addDebt(
        personId: widget.personId,
        type: _type,
        description: description,
        amountCents: amountCents,
        createdAt: DateTime.now(),
        dueDate: _dueDate,
      );
      // `addDebt` no devuelve la deuda creada; como internamente la agrega
      // al final de `_debts` (ver DebtsProvider.addDebt), la última deuda
      // de la lista es la recién creada y de ahí se obtiene su id para
      // programar el recordatorio.
      debtId = provider.debts.last.id;
    }

    await _syncReminder(notificationService, debtId, description);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  NotificationService? _readNotificationService() {
    try {
      return context.read<NotificationService>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncReminder(
    NotificationService? notificationService,
    String debtId,
    String description,
  ) async {
    if (notificationService == null) return;
    try {
      if (_dueDate != null) {
        await notificationService.scheduleDebtDueReminder(
          debtId: debtId,
          title: 'Vencimiento de deuda',
          body: description,
          dueDate: _dueDate!,
        );
      } else {
        await notificationService.cancelReminder(debtId);
      }
    } catch (_) {
      // Los recordatorios son un nice-to-have: un fallo al programar o
      // cancelar la notificación no debe impedir guardar la deuda.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar deuda' : 'Agregar deuda')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SegmentedButton<DebtType>(
                segments: [
                  ButtonSegment(value: DebtType.owedToMe, label: Text(DebtType.owedToMe.label)),
                  ButtonSegment(value: DebtType.iOwe, label: Text(DebtType.iOwe.label)),
                ],
                selected: {_type},
                onSelectionChanged: (selection) => setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (value) => validateRequiredText(value, fieldName: 'La descripción'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Monto'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: validateAmountInput,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _dueDate == null ? 'Sin fecha de vencimiento' : 'Vence: ${_formatDate(_dueDate!)}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _pickDueDate,
                    ),
                    if (_dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _dueDate = null),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _submit, child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
