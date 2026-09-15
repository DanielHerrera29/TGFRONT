import 'package:flutter/material.dart';
import '../compartir_orden_whatsapp.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../borrador_orden.dart';

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
    _ordenes = token == null ? Future.value([]) : _cargarOrdenes(token);
  }

  Future<List<OrdenEscoltaResumen>> _cargarOrdenes(String token) async {
    final userId = context.read<AuthProvider>().user!.id;
    final locales = await BorradorOrden.locales(userId);
    List<OrdenEscoltaResumen> rows;
    try {
      rows = await ApiService.listarOrdenesEscolta(token);
    } catch (_) {
      if (locales.isEmpty) rethrow;
      rows = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin conexión al historial. Se muestran los borradores de este navegador.',
            ),
          ),
        );
      }
    }
    final ids = rows.map((o) => o.clientOrderId).toSet();
    for (final draft in locales) {
      if (ids.contains(draft['clientOrderId'])) continue;
      final f = Map<String, dynamic>.from(draft['fields']);
      rows.insert(
        0,
        OrdenEscoltaResumen.fromJson({
          'client_order_id': draft['clientOrderId'],
          'created_by': userId,
          'estado_captura': 'LOCAL',
          'empresa': f['empresa'],
          'fecha': f['fecha'],
          'placa_camabaja': f['placaCamabaja'],
        }),
      );
    }
    return rows;
  }

  Future<void> _abrirOrden(OrdenEscoltaResumen orden) async {
    if (orden.clientOrderId != null &&
        orden.createdBy == context.read<AuthProvider>().user?.id &&
        orden.emailEnviadoAt == null) {
      await context.push('/ordenes-escolta/editar/${orden.clientOrderId}');
      if (mounted) setState(_recargar);
    } else if (orden.tienePdf) {
      await _abrirPdf(orden);
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Orden ${orden.numeroVisible}'),
          content: Text(
            '${orden.empresa}\n${orden.placaCamabaja}\nEsta orden no dispone de un borrador editable para este usuario.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
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
          tooltip: 'Cerrar sesión',
          onPressed: context.read<AuthProvider>().logout,
          icon: const Icon(Icons.logout),
        ),
        IconButton(
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(_recargar),
        ),
        IconButton(
          tooltip: 'Nueva orden',
          icon: const Icon(Icons.add),
          onPressed: () => context.push('/ordenes-escolta/nueva').then((_) {
            if (mounted) setState(_recargar);
          }),
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
                  : orden.estadoCaptura == 'LOCAL'
                  ? 'Borrador local · pendiente de guardar'
                  : orden.estadoCaptura == 'BORRADOR'
                  ? 'Borrador'
                  : orden.emailError != null
                  ? 'Correo pendiente'
                  : 'Generada';
              return Card(
                child: ListTile(
                  onTap: () => _abrirOrden(orden),
                  leading: CircleAvatar(
                    child: const Icon(Icons.directions_car_outlined),
                  ),
                  title: Text(
                    orden.estadoCaptura == 'LOCAL' ||
                            orden.estadoCaptura == 'BORRADOR'
                        ? 'Borrador sin enviar'
                        : 'Orden No. ${orden.numeroVisible}',
                  ),
                  subtitle: Text(
                    '${orden.empresa}\n${DateFormat('dd/MM/yyyy').format(orden.fecha)}  -  ${orden.placaCamabaja}${orden.placaEscolta == null || orden.placaEscolta!.isEmpty ? '' : '  /  ${orden.placaEscolta}'}\n$estado',
                  ),
                  isThreeLine: true,
                  trailing: orden.tienePdf
                      ? PopupMenuButton<String>(
                          tooltip: 'Opciones del PDF',
                          onSelected: (value) => value == 'pdf'
                              ? _abrirPdf(orden)
                              : _compartir(orden),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'pdf',
                              child: Text('Abrir PDF'),
                            ),
                            PopupMenuItem(
                              value: 'whatsapp',
                              child: Text('Compartir por WhatsApp'),
                            ),
                          ],
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

  bool _compartiendo = false;
  Future<void> _compartir(OrdenEscoltaResumen orden) async {
    if (_compartiendo) return;
    final token = context.read<AuthProvider>().user?.apiToken;
    if (token == null) return;
    _compartiendo = true;
    try {
      final pdf = await ApiService.descargarPdfOrden(token, orden.id);
      final d = await ApiService.detalleCompartirOrden(orden.id);
      final viajes = List<Map<String, dynamic>>.from(
        (d['ordenes_escolta_items'] as List).map(
          (v) => Map<String, dynamic>.from(v),
        ),
      );
      viajes.sort(
        (a, b) => (a['posicion'] as int).compareTo(b['posicion'] as int),
      );
      final numero =
          d['codigo_orden']?.toString() ?? d['consecutivo'].toString();
      final mensaje =
          'Orden de escolta No. $numero\nFecha: ${d['fecha']}\nCliente: ${d['empresa']}\nCamabaja: ${d['placa_camabaja']}\nEscolta: ${d['nombre_escolta']}\nPlaca escolta: ${d['placa_escolta']}\n${viajes.map((v) => 'Viaje ${v['posicion']}: ${v['maquina']} · ${v['origen']} → ${v['destino']}').join('\n')}\nObservaciones: ${d['observaciones'] ?? ''}';
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text('Compartir orden ${orden.numeroVisible}'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                CompartirOrdenWhatsapp(
                  pdf: pdf,
                  mensaje: mensaje,
                  nombreArchivo: 'orden_escolta_${orden.numeroVisible}.pdf',
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo preparar el PDF para WhatsApp. Reintente desde esta misma orden.',
            ),
          ),
        );
      }
    } finally {
      _compartiendo = false;
    }
  }
}
