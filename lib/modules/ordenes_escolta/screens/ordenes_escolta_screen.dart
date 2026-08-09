import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class OrdenesEscoltaScreen extends StatefulWidget {
  const OrdenesEscoltaScreen({super.key});

  @override
  State<OrdenesEscoltaScreen> createState() => _OrdenesEscoltaScreenState();
}

class _OrdenesEscoltaScreenState extends State<OrdenesEscoltaScreen> {
  late Future<List<OrdenEscoltaResumen>> _ordenes;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final token = context.read<AuthProvider>().user?.apiToken;
    _ordenes = token == null
        ? Future.value([])
        : ApiService.listarOrdenesEscolta(token);
  }

  Future<void> _abrirPdf(OrdenEscoltaResumen orden) async {
    final token = context.read<AuthProvider>().user?.apiToken;
    if (token == null) return;
    try {
      final url = await ApiService.urlPdfOrdenEscolta(
        token: token,
        ordenId: orden.id,
      );
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible abrir el PDF.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ordenes de escolta'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(_recargar),
        ),
        IconButton(
          tooltip: 'Nueva orden',
          icon: const Icon(Icons.add),
          onPressed: () => context
              .push('/ordenes-escolta/nueva')
              .then((_) => setState(_recargar)),
        ),
      ],
    ),
    body: FutureBuilder<List<OrdenEscoltaResumen>>(
      future: _ordenes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(_recargar),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          );
        }
        final ordenes = snapshot.data ?? [];
        if (ordenes.isEmpty) {
          return const Center(
            child: Text('No hay ordenes de escolta creadas.'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_recargar),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ordenes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final orden = ordenes[index];
              final estado = orden.emailEnviadoAt != null
                  ? 'Enviada'
                  : orden.emailError != null
                  ? 'Correo pendiente'
                  : 'Generada';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(orden.consecutivo.toString().padLeft(2, '0')),
                  ),
                  title: Text(
                    'Orden No. ${orden.consecutivo.toString().padLeft(5, '0')}',
                  ),
                  subtitle: Text(
                    '${orden.empresa}\n${DateFormat('dd/MM/yyyy').format(orden.fecha)}  -  ${orden.placaCamabaja}${orden.placaEscolta == null || orden.placaEscolta!.isEmpty ? '' : '  /  ${orden.placaEscolta}'}\n$estado',
                  ),
                  isThreeLine: true,
                  trailing: orden.tienePdf
                      ? IconButton(
                          tooltip: 'Abrir PDF',
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          onPressed: () => _abrirPdf(orden),
                        )
                      : const Icon(Icons.pending_outlined),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
