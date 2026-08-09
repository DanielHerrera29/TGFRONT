import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/remesas_list_provider.dart';

class RemesasScreen extends StatefulWidget {
  const RemesasScreen({super.key});

  @override
  State<RemesasScreen> createState() => _RemesasScreenState();
}

class _RemesasScreenState extends State<RemesasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RemesasListProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RemesasListProvider>();
    final df = DateFormat('dd/MM/yy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remesas'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              child: Text(
                'Por gestionar (${rp.pendientes.length})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const Tab(child: Text('Todas', style: TextStyle(fontSize: 13))),
          ],
        ),
      ),
      body: rp.loading
          ? const Center(child: CircularProgressIndicator())
          : rp.error != null
              ? _LoadError(message: rp.error!, onRetry: rp.load)
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildList(rp.pendientes, df, rp),
                _buildList(rp.todas, df, rp),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/remesas/nueva'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(List<RemesaListItem> items, DateFormat df, RemesasListProvider rp) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('Sin remesas', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => rp.load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final d = items[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/remesas/${d.id}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(d.consecutivo,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        _StatusBadge(status: d.estado),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (d.clienteNombre.isNotEmpty)
                      Text(d.clienteNombre,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(df.format(d.createdAt),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(width: 12),
                        Icon(Icons.monitor_weight_outlined,
                            size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text('${d.pesoKg} kg',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _NextStep(item: d),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44, color: Colors.red),
              const SizedBox(height: 12),
              const Text('No se pudieron cargar las remesas'),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}

class _NextStep extends StatelessWidget {
  final RemesaListItem item;
  const _NextStep({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.estado == 'generated' && item.estadoManifiesto == 'generated') {
      return const _StepLine(Icons.task_alt_outlined,
          'Siguiente: cumplir la remesa cuando finalice el viaje', Colors.teal);
    }
    if (item.estado == 'generated' && item.estadoManifiesto == 'error_rndc') {
      return _StepLine(Icons.error_outline,
          'Manifiesto pendiente: ${item.errorManifiesto ?? 'revise y reintente'}', Colors.red);
    }
    if (item.estado == 'generated') {
      return const _StepLine(Icons.assignment_outlined,
          'Siguiente: crear manifiesto', Colors.green);
    }
    if (item.estado == 'cumplido') {
      return const _StepLine(Icons.receipt_long_outlined, 'Remesa cumplida', Colors.teal);
    }
    if (item.estado == 'error_rndc') {
      return const _StepLine(Icons.error_outline,
          'Corrija la información y vuelva a enviarla', Colors.red);
    }
    return const _StepLine(Icons.edit_outlined, 'Pendiente de envío al RNDC', Colors.orange);
  }
}

class _StepLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StepLine(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
        ],
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      'draft' =>
        (Colors.grey.withValues(alpha: 0.1), Colors.grey, 'Borrador'),
      'pending_rndc' =>
        (Colors.orange.withValues(alpha: 0.1), Colors.orange, 'Pendiente'),
      'sent_rndc' =>
        (Colors.blue.withValues(alpha: 0.1), Colors.blue, 'Enviada'),
      'error_rndc' =>
        (Colors.red.withValues(alpha: 0.1), Colors.red, 'Error RNDC'),
      'generated' =>
        (Colors.green.withValues(alpha: 0.1), Colors.green, 'Completada'),
      'cumplido' =>
        (Colors.teal.withValues(alpha: 0.1), Colors.teal, 'Cumplida'),
      _ => (Colors.grey.withValues(alpha: 0.1), Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    );
  }
}
