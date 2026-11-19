import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/dashboard_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/money_text.dart';

/// Pantalla de la pestaña "Resumen": tarjetas con los totales globales
/// ("Me deben", "Debo", "Neto") y un gráfico de torta con la proporción
/// entre ambos.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Ver el comentario equivalente en PeopleListScreen: se posterga la
    // carga inicial al primer frame para no notificar listeners durante
    // la fase de build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DashboardProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const LoadingView();
          }
          if (provider.errorMessage != null) {
            return ErrorView(
              message: provider.errorMessage!,
              onRetry: () => provider.refresh(),
            );
          }

          final summary = provider.summary;
          final hasData = summary.totalOwedToMeCents > 0 || summary.totalIOweCents > 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Me deben',
                      cents: summary.totalOwedToMeCents,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Debo',
                      cents: summary.totalIOweCents,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SummaryCard(label: 'Neto', cents: summary.netCents, colorByValue: true),
              const SizedBox(height: 24),
              if (!hasData)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: EmptyState(
                    icon: Icons.pie_chart_outline,
                    message: 'Todavía no hay deudas registradas.',
                  ),
                )
              else
                SizedBox(
                  height: 240,
                  child: PieChart(
                    PieChartData(
                      sections: _buildSections(provider),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<PieChartSectionData> _buildSections(DashboardProvider provider) {
    final colors = <String, Color>{
      'Me deben': Colors.green.shade600,
      'Debo': Colors.red.shade400,
    };

    return provider.chartSlices
        .where((slice) => slice.valueCents > 0)
        .map(
          (slice) => PieChartSectionData(
            value: slice.valueCents / 100.0,
            title: slice.label,
            color: colors[slice.label] ?? Colors.grey,
          ),
        )
        .toList();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.cents, this.colorByValue = false});

  final String label;
  final int cents;
  final bool colorByValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            MoneyText(
              cents: cents,
              colorByValue: colorByValue,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
