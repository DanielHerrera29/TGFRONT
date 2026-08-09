import 'package:flutter/foundation.dart';

import '../../../services/api_service.dart';

typedef HistoryDataLoader = Future<List<DispatchesViewItem>> Function();

class DispatchesViewItem {
  final String remesaId;
  final String? remesaConsecutivo;
  final String? manifiestoId;
  final String? manifiestoConsecutivo;
  final String remesaEstado;
  final String? manifiestoEstado;
  final String? clienteNombre;
  final String? conductorNombre;
  final String? placaVehiculo;
  final String? errorDetalle;
  final String? errorOrigen;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DispatchesViewItem({
    required this.remesaId,
    this.remesaConsecutivo,
    this.manifiestoId,
    this.manifiestoConsecutivo,
    required this.remesaEstado,
    this.manifiestoEstado,
    this.clienteNombre,
    this.conductorNombre,
    this.placaVehiculo,
    this.errorDetalle,
    this.errorOrigen,
    required this.createdAt,
    this.updatedAt,
  });

  String get estado {
    if (errorDetalle?.trim().isNotEmpty == true ||
        remesaEstado == 'error_rndc' ||
        manifiestoEstado == 'error_rndc') {
      return 'error_rndc';
    }
    return manifiestoEstado ?? remesaEstado;
  }

  bool get hasManifiesto => manifiestoId?.isNotEmpty == true;

  String get statusLabel => switch (estado) {
    'draft' => 'Borrador',
    'pending_rndc' => 'En proceso RNDC',
    'sent_rndc' => 'Remesa aceptada',
    'generated' => hasManifiesto ? 'Manifiesto activo' : 'Generada',
    'pendiente' => 'Pendiente',
    'completado' || 'completada' || 'cumplido' => 'Completado',
    'anulado' => 'Anulado',
    'error_rndc' => 'Requiere atención',
    _ => estado.replaceAll('_', ' '),
  };

  String get nextAction {
    if (estado == 'error_rndc') {
      return 'Revisar el error, corregir los datos y validar antes de reenviar.';
    }
    if (estado == 'draft') {
      return 'Revisar los datos y enviar la remesa al RNDC.';
    }
    if (estado == 'pending_rndc') {
      return 'Esperar o consultar la respuesta del RNDC antes de reenviar.';
    }
    if (!hasManifiesto && (estado == 'sent_rndc' || estado == 'generated')) {
      return 'Crear el manifiesto asociado a esta remesa.';
    }
    if (hasManifiesto && (estado == 'generated' || estado == 'pendiente')) {
      return 'Revisar firmas pendientes y completar el manifiesto.';
    }
    if (estado == 'completado' ||
        estado == 'completada' ||
        estado == 'cumplido') {
      return 'Proceso finalizado. Consultar el detalle para auditoría.';
    }
    if (estado == 'anulado') {
      return 'Proceso anulado. No requiere una acción operativa.';
    }
    return 'Abrir el detalle y verificar el estado operativo.';
  }

  String get sourceLabel =>
      hasManifiesto ? 'Supabase: remesas + manifiestos' : 'Supabase: remesas';

  factory DispatchesViewItem.fromRecords(
    Map<String, dynamic> remesa,
    Map<String, dynamic>? manifiesto,
  ) {
    final remesaError = remesa['error_detalle']?.toString();
    final manifiestoError = manifiesto?['error_detalle']?.toString();
    final error = manifiestoError?.trim().isNotEmpty == true
        ? manifiestoError
        : remesaError;
    final updatedCandidates = [
      _parseDate(remesa['updated_at']),
      _parseDate(manifiesto?['updated_at']),
    ].whereType<DateTime>().toList();
    updatedCandidates.sort();

    return DispatchesViewItem(
      remesaId: remesa['id']?.toString() ?? '',
      remesaConsecutivo: remesa['consecutivo']?.toString(),
      manifiestoId: manifiesto?['id']?.toString(),
      manifiestoConsecutivo: manifiesto?['consecutivo']?.toString(),
      remesaEstado: remesa['estado']?.toString() ?? 'draft',
      manifiestoEstado: manifiesto?['estado']?.toString(),
      clienteNombre: remesa['cliente_nombre']?.toString(),
      conductorNombre: manifiesto?['conductor_nombre']?.toString(),
      placaVehiculo: manifiesto?['placa_vehiculo']?.toString(),
      errorDetalle: error,
      errorOrigen: manifiestoError?.trim().isNotEmpty == true
          ? 'Manifiesto RNDC'
          : remesaError?.trim().isNotEmpty == true
          ? 'Remesa RNDC'
          : null,
      createdAt: _parseDate(remesa['created_at']) ?? DateTime.now(),
      updatedAt: updatedCandidates.isEmpty ? null : updatedCandidates.last,
    );
  }

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}

class HistoryProvider extends ChangeNotifier {
  final HistoryDataLoader _loader;
  final List<DispatchesViewItem> _allItems = [];

  String _filterStatus = 'all';
  String _searchQuery = '';
  bool _loading = false;
  String? _error;

  HistoryProvider({HistoryDataLoader? loader})
    : _loader = loader ?? _loadFromSupabase;

  String get filterStatus => _filterStatus;
  String get searchQuery => _searchQuery;
  bool get loading => _loading;
  String? get error => _error;
  int get totalCount => _allItems.length;
  int get errorCount =>
      _allItems.where((item) => item.estado == 'error_rndc').length;
  int get pendingCount => _allItems
      .where(
        (item) =>
            item.estado != 'error_rndc' &&
            item.estado != 'completado' &&
            item.estado != 'completada' &&
            item.estado != 'cumplido' &&
            item.estado != 'anulado',
      )
      .length;

  List<DispatchesViewItem> get items {
    Iterable<DispatchesViewItem> result = _allItems;
    if (_filterStatus == 'error_rndc') {
      result = result.where((item) => item.estado == 'error_rndc');
    } else if (_filterStatus == 'completed') {
      result = result.where(
        (item) =>
            item.estado == 'completado' ||
            item.estado == 'completada' ||
            item.estado == 'cumplido',
      );
    } else if (_filterStatus == 'pending') {
      result = result.where(
        (item) =>
            item.estado != 'error_rndc' &&
            item.estado != 'completado' &&
            item.estado != 'completada' &&
            item.estado != 'cumplido' &&
            item.estado != 'anulado',
      );
    }
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where(
        (item) =>
            [
              item.clienteNombre,
              item.conductorNombre,
              item.placaVehiculo,
              item.remesaConsecutivo,
              item.manifiestoConsecutivo,
              item.errorDetalle,
            ].whereType<String>().any(
              (value) => value.toLowerCase().contains(query),
            ),
      );
    }
    return result.toList(growable: false);
  }

  void setFilter(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _filterStatus = 'all';
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final loaded = await _loader();
      _allItems
        ..clear()
        ..addAll(loaded);
    } catch (error, stackTrace) {
      debugPrint('Error loading history: $error\n$stackTrace');
      _error =
          'No fue posible consultar remesas y manifiestos. '
          'Verifica la conexión y los permisos de Supabase.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  static Future<List<DispatchesViewItem>> _loadFromSupabase() async {
    final remesaResponses = await ApiService.listarRemesas();
    final manifiestoResponses = await ApiService.listarManifiestos();
    final remesas = remesaResponses
        .map((row) => Map<String, dynamic>.from(row['remesa'] as Map))
        .toList();
    final manifiestos = manifiestoResponses
        .map((row) => Map<String, dynamic>.from(row['manifiesto'] as Map))
        .toList();

    final latestByRemesa = <String, Map<String, dynamic>>{};
    for (final row in manifiestos) {
      final remesaId = row['remesa_id']?.toString();
      if (remesaId != null && !latestByRemesa.containsKey(remesaId)) {
        latestByRemesa[remesaId] = row;
      }
    }

    return remesas
        .map<DispatchesViewItem>(
          (remesa) => DispatchesViewItem.fromRecords(
            remesa,
            latestByRemesa[remesa['id']?.toString()],
          ),
        )
        .toList(growable: false);
  }
}
