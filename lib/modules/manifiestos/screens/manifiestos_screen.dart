import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/manifiestos_list_provider.dart';

class ManifiestosScreen extends StatefulWidget {
  const ManifiestosScreen({super.key});

  @override
  State<ManifiestosScreen> createState() => _ManifiestosScreenState();
}

class _ManifiestosScreenState extends State<ManifiestosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManifiestosListProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<ManifiestosListProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manifiestos'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              child: Text('Activos (${mp.activos.length})',
                  style: const TextStyle(fontSize: 13)),
            ),
            Tab(
              child: Text('Completados (${mp.completados.length})',
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
      body: mp.loading
          ? const Center(child: CircularProgressIndicator())
          : mp.error != null
              ? _LoadError(message: mp.error!, onRetry: mp.load)
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildList(mp.activos, mp),
                _buildList(mp.completados, mp),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/manifiestos/nuevo'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(List items, ManifiestosListProvider mp) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('Sin manifiestos', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => mp.load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final d = items[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/manifiestos/${d.id}'),
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
                    Row(
                      children: [
                        Icon(Icons.directions_car,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(d.placaVehiculo,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 16),
                        Icon(Icons.person_outline,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(d.conductorLabel,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    if (d.remesaConsecutivo != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.link,
                              size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text('Remesa: ${d.remesaConsecutivo}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ],
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
              const Text('No se pudieron cargar los manifiestos'),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      'generated' =>
        (Colors.blue.withValues(alpha: 0.1), Colors.blue, 'Activo'),
      'completado' =>
        (Colors.green.withValues(alpha: 0.1), Colors.green, 'Completado'),
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
