import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/people_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/balance_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import 'person_detail_screen.dart';

/// Pantalla principal de la pestaña "Personas": lista todas las personas
/// con su saldo neto, permite agregar una nueva y eliminar (con deshacer)
/// mediante swipe.
class PeopleListScreen extends StatefulWidget {
  const PeopleListScreen({super.key});

  @override
  State<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends State<PeopleListScreen> {
  @override
  void initState() {
    super.initState();
    // Se agenda la carga con addPostFrameCallback en lugar de llamarla
    // directamente: `loadPeople()` notifica listeners de forma síncrona
    // antes de su primer `await` (para poner `isLoading = true`), y
    // notificar durante la fase de build ("setState() called during
    // build") es un error de Flutter. Postergarla al primer frame evita
    // ese problema de forma consistente en todas las pantallas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PeopleProvider>().loadPeople();
    });
  }

  Future<void> _showAddPersonSheet() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Agregar persona',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: validatePersonName,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                  validator: validateOptionalPhone,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Nota (opcional)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    final note = noteController.text.trim();
                    await context.read<PeopleProvider>().addPerson(
                          name: name,
                          phone: phone.isEmpty ? null : phone,
                          note: note.isEmpty ? null : note,
                        );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PeopleProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.people.isEmpty) {
            return const LoadingView();
          }
          if (provider.errorMessage != null) {
            return ErrorView(
              message: provider.errorMessage!,
              onRetry: () => provider.loadPeople(),
            );
          }
          if (provider.people.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              message: 'Todavía no agregaste a nadie.',
              actionLabel: 'Agregar persona',
              onAction: _showAddPersonSheet,
            );
          }

          final people = provider.people;
          return ListView.builder(
            itemCount: people.length,
            itemBuilder: (context, index) {
              final person = people[index];
              return Dismissible(
                key: ValueKey(person.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) {
                  final messenger = ScaffoldMessenger.of(context);
                  final peopleProvider = context.read<PeopleProvider>();
                  peopleProvider.deletePerson(person.id);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${person.name} eliminada'),
                      action: SnackBarAction(
                        label: 'Deshacer',
                        onPressed: () => peopleProvider.restoreLastDeleted(),
                      ),
                    ),
                  );
                },
                child: ListTile(
                  title: Text(person.name),
                  subtitle: person.phone != null ? Text(person.phone!) : null,
                  trailing: BalanceBadge(
                    cents: provider.netBalanceForPerson(person.id),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonDetailScreen(personId: person.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPersonSheet,
        tooltip: 'Agregar persona',
        child: const Icon(Icons.add),
      ),
    );
  }
}
