import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';

class RemesaListItem {
  final String id;
  final String consecutivo;
  final String clienteNombre;
  final String estado;
  final String? estadoManifiesto;
  final String? errorManifiesto;
  final double pesoKg;
  final DateTime createdAt;

  RemesaListItem({
    required this.id,
    required this.consecutivo,
    this.clienteNombre = '',
    required this.estado,
    this.estadoManifiesto,
    this.errorManifiesto,
    this.pesoKg = 0,
    required this.createdAt,
  });

  factory RemesaListItem.fromMap(
    Map<String, dynamic> m, {
    Map<String, dynamic>? manifiesto,
  }) => RemesaListItem(
        id: m['id']?.toString() ?? '',
        consecutivo: m['consecutivo']?.toString() ?? '',
        clienteNombre: m['cliente_nombre']?.toString() ?? '',
        estado: m['estado']?.toString() ?? 'draft',
        estadoManifiesto: manifiesto?['estado']?.toString(),
        errorManifiesto: manifiesto?['error_detalle']?.toString(),
        pesoKg: (m['peso_kg'] ?? 0).toDouble(),
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

class RemesasListProvider extends ChangeNotifier {
  List<RemesaListItem> _todas = [];
  List<RemesaListItem> _pendientes = [];
  bool _loading = false;
  String? _error;

  List<RemesaListItem> get todas => _todas;
  List<RemesaListItem> get pendientes => _pendientes;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await ApiService.listarRemesas();
      _todas = rows
          .map<RemesaListItem>((row) {
            final remesa = Map<String, dynamic>.from(row['remesa'] as Map);
            return RemesaListItem.fromMap(
              remesa,
              manifiesto: {
                'estado': row['estado_manifiesto'],
                'error_detalle': row['error_manifiesto'],
              },
            );
          })
          .toList();

      _pendientes = _todas
          .where((r) => r.estado != 'cumplido' && r.estado != 'anulado')
          .toList();
    } catch (e) {
      debugPrint('Error loading remesas: $e');
      _error = 'No fue posible cargar las remesas: $e';
    }

    _loading = false;
    notifyListeners();
  }
}
