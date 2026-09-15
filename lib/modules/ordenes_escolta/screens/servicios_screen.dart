import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../borrador_orden.dart';

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key});
  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  late Future<List<Map<String, dynamic>>> _rows;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final token = context.read<AuthProvider>().user?.apiToken;
    _rows = token == null
        ? Future.error('Inicie sesión')
        : BorradorOrden.list(token);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Servicios registrados'),
      actions: [
        IconButton(
          onPressed: () => setState(_load),
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: () => setState(_load),
              child: const Text('Reintentar consulta'),
            ),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const Center(
            child: Text('No hay servicios registrados todavía.'),
          );
        }
        return ListView.builder(
          itemCount: rows.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Últimos 200 servicios. Los borradores pueden tener información pendiente.',
                ),
              );
            }
            final r = rows[index - 1];
            return ListTile(
              title: Text(
                'Servicio ${r['folio']} · ${r['empresa'] ?? 'Cliente pendiente'}',
              ),
              subtitle: Text(
                '${r['maquina'] ?? 'Máquina pendiente'}\n${r['origen'] ?? 'Origen pendiente'} → ${r['destino'] ?? 'Destino pendiente'}\n${r['estado_operativo']}',
              ),
              isThreeLine: true,
            );
          },
        );
      },
    ),
  );
}
