import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../../../data/datasource/local_store.dart';
import '../../../data/models/manifiesto.dart';
import '../../../data/models/remesa.dart';
import '../../../services/api_service.dart';

class ManifiestoProvider extends ChangeNotifier {
  final LocalStore _store;

  ManifiestoProvider(this._store);

  Manifiesto? _manifiestoActual;
  bool _saving = false;
  bool _loading = false;
  String? _error;
  ManifiestoRndcResult? _ultimoResultado;

  Manifiesto? get manifiestoActual => _manifiestoActual;
  bool get saving => _saving;
  bool get loading => _loading;
  String? get error => _error;
  ManifiestoRndcResult? get ultimoResultado => _ultimoResultado;

  void prepararDesdeRemesa(Remesa remesa) {
    _manifiestoActual = Manifiesto(
      consecutivo: '',
      remesaId: remesa.id,
      placaVehiculo: '',
      conductorCedula: '',
      valorViaje: 0,
      valorAnticipo: 0,
      observaciones: remesa.observaciones,
    );
    notifyListeners();
  }

  void updatePlaca(String v) {
    _manifiestoActual = _manifiestoActual != null
        ? Manifiesto(
            id: _manifiestoActual!.id,
            consecutivo: _manifiestoActual!.consecutivo,
            remesaId: _manifiestoActual!.remesaId,
            placaVehiculo: v,
            placaRemolque: _manifiestoActual!.placaRemolque,
            conductorCedula: _manifiestoActual!.conductorCedula,
            conductorNombre: _manifiestoActual!.conductorNombre,
            valorViaje: _manifiestoActual!.valorViaje,
            valorAnticipo: _manifiestoActual!.valorAnticipo,
            observaciones: _manifiestoActual!.observaciones,
            estado: _manifiestoActual!.estado,
          )
        : null;
    notifyListeners();
  }

  void updateConductorCedula(String v) {
    _manifiestoActual = _manifiestoActual != null
        ? Manifiesto(
            id: _manifiestoActual!.id,
            consecutivo: _manifiestoActual!.consecutivo,
            remesaId: _manifiestoActual!.remesaId,
            placaVehiculo: _manifiestoActual!.placaVehiculo,
            placaRemolque: _manifiestoActual!.placaRemolque,
            conductorCedula: v,
            conductorNombre: _manifiestoActual!.conductorNombre,
            valorViaje: _manifiestoActual!.valorViaje,
            valorAnticipo: _manifiestoActual!.valorAnticipo,
            observaciones: _manifiestoActual!.observaciones,
            estado: _manifiestoActual!.estado,
          )
        : null;
    notifyListeners();
  }

  void updateValorViaje(double v) {
    _manifiestoActual = _manifiestoActual != null
        ? Manifiesto(
            id: _manifiestoActual!.id,
            consecutivo: _manifiestoActual!.consecutivo,
            remesaId: _manifiestoActual!.remesaId,
            placaVehiculo: _manifiestoActual!.placaVehiculo,
            placaRemolque: _manifiestoActual!.placaRemolque,
            conductorCedula: _manifiestoActual!.conductorCedula,
            conductorNombre: _manifiestoActual!.conductorNombre,
            valorViaje: v,
            valorAnticipo: _manifiestoActual!.valorAnticipo,
            observaciones: _manifiestoActual!.observaciones,
            estado: _manifiestoActual!.estado,
          )
        : null;
    notifyListeners();
  }

  void updateValorAnticipo(double v) {
    _manifiestoActual = _manifiestoActual != null
        ? Manifiesto(
            id: _manifiestoActual!.id,
            consecutivo: _manifiestoActual!.consecutivo,
            remesaId: _manifiestoActual!.remesaId,
            placaVehiculo: _manifiestoActual!.placaVehiculo,
            placaRemolque: _manifiestoActual!.placaRemolque,
            conductorCedula: _manifiestoActual!.conductorCedula,
            conductorNombre: _manifiestoActual!.conductorNombre,
            valorViaje: _manifiestoActual!.valorViaje,
            valorAnticipo: v,
            observaciones: _manifiestoActual!.observaciones,
            estado: _manifiestoActual!.estado,
          )
        : null;
    notifyListeners();
  }

  void clear() {
    _manifiestoActual = null;
    _error = null;
    _ultimoResultado = null;
    notifyListeners();
  }

  Future<bool> saveManifiesto() async {
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      String consecutivo;
      try {
        consecutivo = await SupabaseService.client
            .rpc('generar_consecutivo_manifiesto');
      } catch (_) {
        consecutivo = 'TEMP-${DateTime.now().millisecondsSinceEpoch}';
      }

      final m = _manifiestoActual!;
      final manifiesto = Manifiesto(
        consecutivo: consecutivo,
        remesaId: m.remesaId,
        placaVehiculo: m.placaVehiculo,
        conductorCedula: m.conductorCedula,
        valorViaje: m.valorViaje,
        valorAnticipo: m.valorAnticipo,
        estado: 'draft',
        createdBy: _store.currentUser?.id,
      );

      final row = await SupabaseService.insert(
          'manifiestos', manifiesto.toInsertMap());
      _manifiestoActual = Manifiesto.fromMap(row);
      _saving = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving manifiesto: $e');
      _error = 'Error al guardar manifiesto';
      _saving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> enviarARndc({
    required String rndcUsername,
    required String rndcPassword,
  }) async {
    if (_manifiestoActual == null) return false;

    _loading = true;
    _error = null;
    _ultimoResultado = null;
    notifyListeners();

    final resultado = await ApiService.generarManifiesto(
      rndcUsername: rndcUsername,
      rndcPassword: rndcPassword,
      manifiesto: _manifiestoActual!,
    );

    _ultimoResultado = resultado;

    if (resultado.exito) {
      _manifiestoActual = _manifiestoActual!.copyWith(
        estado: 'generated',
        radicadoRndc: resultado.numeroAutorizacion,
        numeroAutorizacion: resultado.numeroAutorizacion,
        consecutivo: resultado.consecutivo,
      );
    } else {
      _error = resultado.error;
    }

    _loading = false;
    notifyListeners();
    return resultado.exito;
  }
}
