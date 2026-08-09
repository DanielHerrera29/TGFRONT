import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../manifiestos/providers/manifiestos_list_provider.dart';
import '../../remesas/providers/remesas_list_provider.dart';
import '../../settings/providers/settings_provider.dart';

class DashboardScreen extends StatefulWidget {
  final bool autoLoad;

  const DashboardScreen({super.key, this.autoLoad = true});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<SettingsProvider>().load(),
      context.read<RemesasListProvider>().load(),
      context.read<ManifiestosListProvider>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final remesas = context.watch<RemesasListProvider>();
    final manifiestos = context.watch<ManifiestosListProvider>();
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final compactAppBar = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: AppSpacing.lg,
        title: const _Brand(),
        actions: [
          if (!compactAppBar) ...[
            IconButton(
              tooltip: 'Configuración',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: auth.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.section,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WelcomePanel(
                          userName: auth.user?.name ?? 'Operador',
                          simulation: settings.simulation,
                          onCreateDispatch: () => context.push('/dispatch'),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _OperationalSummary(
                          remesas: remesas.pendientes.length,
                          manifiestos: manifiestos.activos.length,
                          loading: remesas.loading || manifiestos.loading,
                        ),
                        if (remesas.error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _InlineError(
                            message: 'No pudimos actualizar todos los datos.',
                            onRetry: _refresh,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Accesos rápidos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Gestiona las operaciones frecuentes desde un solo lugar.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ActionGrid(isAdmin: auth.user?.isAdmin == true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.local_shipping_outlined, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'CargoDespacho',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  final String userName;
  final bool simulation;
  final VoidCallback onCreateDispatch;

  const _WelcomePanel({
    required this.userName,
    required this.simulation,
    required this.onCreateDispatch,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final introduction = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EnvironmentPill(simulation: simulation),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Hola, $userName',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: colors.onPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tu operación de transporte, clara y al día.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.82),
                ),
              ),
            ],
          );
          final action = FilledButton.icon(
            key: const Key('new-dispatch-button'),
            onPressed: onCreateDispatch,
            style: FilledButton.styleFrom(
              backgroundColor: colors.onPrimary,
              foregroundColor: colors.primary,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo despacho'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                introduction,
                const SizedBox(height: AppSpacing.xl),
                action,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: introduction),
              const SizedBox(width: AppSpacing.xl),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _EnvironmentPill extends StatelessWidget {
  final bool simulation;

  const _EnvironmentPill({required this.simulation});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: simulation
          ? 'Modo simulación activo'
          : 'Modo operación real activo',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.onPrimary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.onPrimary.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              simulation ? Icons.science_outlined : Icons.verified_outlined,
              size: 18,
              color: colors.onPrimary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                simulation ? 'Modo simulación' : 'Operación real',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onPrimary,
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

class _OperationalSummary extends StatelessWidget {
  final int remesas;
  final int manifiestos;
  final bool loading;

  const _OperationalSummary({
    required this.remesas,
    required this.manifiestos,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Resumen operativo',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 520;
          final cards = [
            _MetricCard(
              label: 'Remesas pendientes',
              value: remesas,
              icon: Icons.description_outlined,
              loading: loading,
            ),
            _MetricCard(
              label: 'Manifiestos activos',
              value: manifiestos,
              icon: Icons.assignment_outlined,
              loading: loading,
            ),
          ];
          if (vertical) {
            return Column(
              children: [
                cards.first,
                const SizedBox(height: AppSpacing.md),
                cards.last,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: cards.first),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: cards.last),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final bool loading;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: colors.onSecondaryContainer),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _ActionGrid extends StatelessWidget {
  final bool isAdmin;

  const _ActionGrid({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final actions = <_DashboardAction>[
      _DashboardAction(
        title: 'Órdenes de escolta',
        description: 'Crea órdenes internas y su PDF.',
        icon: Icons.assignment_turned_in_outlined,
        route: '/ordenes-escolta',
      ),
      _DashboardAction(
        title: 'Remesas',
        description: 'Consulta pendientes y estados RNDC.',
        icon: Icons.description_outlined,
        route: '/remesas',
      ),
      _DashboardAction(
        title: 'Manifiestos',
        description: 'Gestiona manifiestos y cumplimiento.',
        icon: Icons.assignment_outlined,
        route: '/manifiestos',
      ),
      _DashboardAction(
        title: 'Vehículos',
        description: 'Administra la flota registrada.',
        icon: Icons.local_shipping_outlined,
        route: '/vehiculos',
      ),
      _DashboardAction(
        title: 'Pendientes de firma',
        description: 'Revisa firmas que requieren atención.',
        icon: Icons.draw_outlined,
        route: '/manifiestos/pendientes-firma',
      ),
      _DashboardAction(
        title: 'Historial',
        description: 'Consulta operaciones y resultados.',
        icon: Icons.history_rounded,
        route: '/history',
      ),
      _DashboardAction(
        title: 'Configuración',
        description: 'Ajusta empresa y conexión RNDC.',
        icon: Icons.settings_outlined,
        route: '/settings',
      ),
      if (isAdmin)
        _DashboardAction(
          title: 'Gestión de usuarios',
          description: 'Administra accesos y roles.',
          icon: Icons.group_outlined,
          route: '/manage-users',
        ),
      _DashboardAction(
        title: 'Delegar firma',
        description: 'Proceso 75 pendiente de habilitación.',
        icon: Icons.gavel_outlined,
        enabled: false,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final gap = AppSpacing.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _ActionCard(action: action),
              ),
          ],
        );
      },
    );
  }
}

class _DashboardAction {
  final String title;
  final String description;
  final IconData icon;
  final String? route;
  final bool enabled;

  const _DashboardAction({
    required this.title,
    required this.description,
    required this.icon,
    this.route,
    this.enabled = true,
  });
}

class _ActionCard extends StatelessWidget {
  final _DashboardAction action;

  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = action.enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.45);
    return Semantics(
      button: action.enabled,
      enabled: action.enabled,
      label: '${action.title}. ${action.description}',
      child: Card(
        color: action.enabled
            ? colors.surfaceContainerLowest
            : colors.surfaceContainerLow,
        child: InkWell(
          onTap: action.enabled && action.route != null
              ? () => context.push(action.route!)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 132),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: action.enabled
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(action.icon, color: foreground),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: foreground),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          action.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: action.enabled
                                    ? colors.onSurfaceVariant
                                    : foreground,
                              ),
                        ),
                        if (!action.enabled) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Próximamente',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (action.enabled)
                    Icon(Icons.arrow_forward_rounded, color: colors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: colors.onErrorContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
