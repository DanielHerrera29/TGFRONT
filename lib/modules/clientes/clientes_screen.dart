import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/cliente.dart';
import '../auth/providers/auth_provider.dart';
import '../ordenes_escolta/borrador_orden.dart';
import 'crear_cliente_dialog.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> _clientes = [];
  bool _loading = true;
  String? _error;
  String _busqueda = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user?.isAdmin != true) {
      setState(() {
        _loading = false;
        _error = 'Solo administración puede gestionar empresas.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await BorradorOrden.clients(user!.apiToken!);
      if (mounted) {
        setState(() => _clientes = rows.map(Cliente.fromMap).toList());
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudieron cargar las empresas. Reintente la consulta.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editar([Cliente? cliente]) async {
    final token = context.read<AuthProvider>().user?.apiToken;
    if (token == null) return;
    final result = await showDialog<Cliente>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CrearClienteDialog(token: token, cliente: cliente),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente y placas guardados.')),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthProvider>().user?.isAdmin == true;
    final rows = _clientes
        .where(
          (c) => '${c.nombre} ${c.documento} ${c.placasCarga.join(' ')}'
              .toLowerCase()
              .contains(_busqueda),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empresas y clientes'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: !admin
          ? const Center(
              child: Text('Solo administración puede gestionar empresas.'),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar por nombre, documento o placa',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) =>
                            setState(() => _busqueda = v.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _editar(),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear empresa o cliente'),
                      ),
                    ],
                  ),
                ),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                Expanded(
                  child: !_loading && rows.isEmpty
                      ? const Center(
                          child: Text('No hay clientes que mostrar.'),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: rows.length,
                            itemBuilder: (_, i) {
                              final c = rows[i];
                              return ListTile(
                                title: Text(c.nombre),
                                subtitle: Text(
                                  '${c.documento}\n${c.placasCarga.isEmpty ? 'Sin placas de carga' : c.placasCarga.join(', ')}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: () => _editar(c),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
