import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';

class ManifiestoListItem {
  final String id;
  final String consecutivo;
  final String estado;
  final String placaVehiculo;
  final String conductorCedula;
  final String? conductorNombre;
  final String remesaId;
  final String? remesaConsecutivo;

  ManifiestoListItem({
    required this.id,
    required this.consecutivo,
    required this.estado,
    this.placaVehiculo = '',
    this.conductorCedula = '',
    this.conductorNombre,
    required this.remesaId,
    this.remesaConsecutivo,
  });

  String get conductorLabel =>
      conductorNombre ?? conductorCedula;

  factory ManifiestoListItem.fromMap(Map<String, dynamic> m) =>
      ManifiestoListItem(
        id: m['id']?.toString() ?? '',
        consecutivo: m['consecutivo']?.toString() ?? '',
        estado: m['estado']?.toString() ?? 'draft',
        placaVehiculo: m['placa_vehiculo']?.toString() ?? '',
        conductorCedula: m['conductor_cedula']?.toString() ?? '',
        conductorNombre: m['conductor_nombre']?.toString(),
        remesaId: m['remesa_id']?.toString() ?? '',
        remesaConsecutivo: m['remesa_consecutivo']?.toString(),
      );
}

class ManifiestosListProvider extends ChangeNotifier {
  List<ManifiestoListItem> _activos = [];
  List<ManifiestoListItem> _completados = [];
  bool _loading = false;
  String? _error;

  List<ManifiestoListItem> get activos => _activos;
  List<ManifiestoListItem> get completados => _completados;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await ApiService.listarManifiestos();

      final all = rows
          .map<ManifiestoListItem>((row) {
            final manifiesto =
                Map<String, dynamic>.from(row['manifiesto'] as Map);
            manifiesto['remesa_consecutivo'] = row['remesa_consecutivo'];
            return ManifiestoListItem.fromMap(manifiesto);
          })
          .toList();

      _activos =
          all.where((m) => m.estado == 'generated').toList();
      _completados =
          all.where((m) => m.estado == 'completado').toList();
    } catch (e) {
      debugPrint('Error loading manifiestos: $e');
      _error = 'No fue posible cargar los manifiestos: $e';
      _activos = [];
      _completados = [];
    }

    _loading = false;
    notifyListeners();
  }
}
