import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends StatefulWidget {
  final bool autoLoad;

  const HistoryScreen({super.key, this.autoLoad = true});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<HistoryProvider>().load(),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final hasFilters =
        history.filterStatus != 'all' || history.searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial operativo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar historial',
            onPressed: history.loading ? null : history.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: history.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _HistoryIntroduction(),
                        const SizedBox(height: AppSpacing.lg),
                        _Summary(history: history),
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          controller: _searchController,
                          onChanged: history.setSearch,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            labelText: 'Buscar en el historial',
                            hintText:
                                'Cliente, conductor, placa, consecutivo o error',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: history.searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpiar búsqueda',
                                    onPressed: () {
                                      _searchController.clear();
                                      history.setSearch('');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Filters(history: history),
                        if (hasFilters) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                history.clearFilters();
                              },
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('Limpiar filtros'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (history.loading && history.totalCount == 0)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _LoadingState(),
              )
            else if (history.error != null && history.totalCount == 0)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: history.error!,
                  onRetry: history.load,
                ),
              )
            else if (history.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(filtered: hasFilters),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.section,
                ),
                sliver: SliverList.separated(
                  itemCount: history.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = history.items[index];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: _HistoryCard(
                          item: item,
                          onOpen: () =>
                              context.push('/history/${item.remesaId}'),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryIntroduction extends StatelessWidget {
  const _HistoryIntroduction();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.manage_search_rounded, color: colors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seguimiento de remesas y manifiestos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Cada registro explica qué información se encontró, su '
                  'estado actual, el origen de un error y el siguiente paso.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final HistoryProvider history;

  const _Summary({required this.history});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final cards = [
          _SummaryItem(
            label: 'Registros',
            value: history.totalCount,
            icon: Icons.receipt_long_outlined,
          ),
          _SummaryItem(
            label: 'En proceso',
            value: history.pendingCount,
            icon: Icons.timelapse_rounded,
          ),
          _SummaryItem(
            label: 'Con error',
            value: history.errorCount,
            icon: Icons.error_outline_rounded,
            isError: history.errorCount > 0,
          ),
        ];
        if (compact) {
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final card in cards)
                SizedBox(
                  width: (constraints.maxWidth - AppSpacing.sm) / 2,
                  child: card,
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index != cards.length - 1)
                const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final bool isError;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = isError ? colors.error : colors.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final HistoryProvider history;

  const _Filters({required this.history});

  @override
  Widget build(BuildContext context) {
    const filters = {
      'all': 'Todos',
      'pending': 'En proceso',
      'error_rndc': 'Con error',
      'completed': 'Completados',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters.entries) ...[
            ChoiceChip(
              label: Text(filter.value),
              selected: history.filterStatus == filter.key,
              onSelected: (_) => history.setFilter(filter.key),
            ),
            if (filter.key != filters.keys.last)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final DispatchesViewItem item;
  final VoidCallback onOpen;

  const _HistoryCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy, HH:mm');
    final status = _StatusVisual.from(item.estado, colors);
    final lastUpdate = item.updatedAt ?? item.createdAt;

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.clienteNombre?.trim().isNotEmpty == true
                            ? item.clienteNombre!
                            : 'Cliente sin identificar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Remesa ${item.remesaConsecutivo ?? 'sin consecutivo'}'
                        '${item.manifiestoConsecutivo == null ? '' : '  •  Manifiesto ${item.manifiestoConsecutivo}'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  _StatusBadge(label: item.statusLabel, visual: status),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _StateBreakdown(item: item),
              if (item.conductorNombre != null ||
                  item.placaVehiculo != null) ...[
                const SizedBox(height: AppSpacing.md),
                _InfoLine(
                  icon: Icons.local_shipping_outlined,
                  label: 'Transporte',
                  value: [item.placaVehiculo, item.conductorNombre]
                      .whereType<String>()
                      .where((value) => value.trim().isNotEmpty)
                      .join(' • '),
                ),
              ],
              if (item.errorDetalle?.trim().isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorPanel(item: item),
              ],
              const SizedBox(height: AppSpacing.md),
              _NextAction(text: item.nextAction),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: colors.outlineVariant),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                children: [
                  _Metadata(
                    icon: Icons.schedule_outlined,
                    text: 'Actualizado ${dateFormat.format(lastUpdate)}',
                  ),
                  _Metadata(
                    icon: Icons.storage_outlined,
                    text: item.sourceLabel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ver información completa'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateBreakdown extends StatelessWidget {
  final DispatchesViewItem item;

  const _StateBreakdown({required this.item});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        _StateValue(
          label: 'Estado de remesa',
          value: _rawStatusLabel(item.remesaEstado),
        ),
        _StateValue(
          label: 'Estado de manifiesto',
          value: item.manifiestoEstado == null
              ? 'Todavía no existe'
              : _rawStatusLabel(item.manifiestoEstado!),
        ),
      ],
    );
  }
}

class _StateValue extends StatelessWidget {
  final String label;
  final String value;

  const _StateValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final DispatchesViewItem item;

  const _ErrorPanel({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Error de ${item.errorOrigen ?? 'RNDC'}: ${item.errorDetalle}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error en ${item.errorOrigen ?? 'RNDC'}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.errorDetalle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextAction extends StatelessWidget {
  final String text;

  const _NextAction({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.arrow_circle_right_outlined, color: colors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qué sigue', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('$label: $value')),
      ],
    );
  }
}

class _Metadata extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Metadata({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final _StatusVisual visual;

  const _StatusBadge({required this.label, required this.visual});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Estado operativo: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(visual.icon, size: 17, color: visual.foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: visual.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusVisual {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _StatusVisual(this.background, this.foreground, this.icon);

  factory _StatusVisual.from(String status, ColorScheme colors) =>
      switch (status) {
        'error_rndc' => _StatusVisual(
          colors.errorContainer,
          colors.onErrorContainer,
          Icons.error_outline_rounded,
        ),
        'completado' || 'completada' || 'cumplido' => _StatusVisual(
          colors.primaryContainer,
          colors.onPrimaryContainer,
          Icons.check_circle_outline_rounded,
        ),
        'anulado' => _StatusVisual(
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant,
          Icons.cancel_outlined,
        ),
        _ => _StatusVisual(
          colors.tertiaryContainer,
          colors.onTertiaryContainer,
          Icons.timelapse_rounded,
        ),
      };
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: AppSpacing.md),
        Text('Consultando remesas y manifiestos...'),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 52, color: colors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No se pudo cargar el historial',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered;

  const _EmptyState({required this.filtered});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 52,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              filtered ? 'No hay coincidencias' : 'No hay remesas registradas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              filtered
                  ? 'Prueba con otro término o limpia los filtros.'
                  : 'Los registros aparecerán cuando existan datos en Supabase.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _rawStatusLabel(String status) => switch (status) {
  'draft' => 'Borrador',
  'pending_rndc' => 'Pendiente RNDC',
  'sent_rndc' => 'Aceptada por RNDC',
  'error_rndc' => 'Error RNDC',
  'generated' => 'Generado',
  'pendiente' => 'Pendiente',
  'completado' || 'completada' => 'Completado',
  'cumplido' => 'Cumplido',
  'anulado' => 'Anulado',
  _ => status.replaceAll('_', ' '),
};
