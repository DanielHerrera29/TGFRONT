import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../../../data/models/vehiculo.dart';
import '../../../services/api_service.dart';

class VehiculosProvider extends ChangeNotifier {
  List<VehiculoListItem> _vehiculos = [];
  bool _loading = false;
  String? _error;

  List<MasterDataItem> _configuraciones = [];
  List<MasterDataItem> _tiposCarroceria = [];
  List<MasterDataItem> _tiposIdentificacion = [];

  bool _loadingMaestro = false;
  String? _maestroError;

  List<VehiculoListItem> get vehiculos => _vehiculos;
  bool get loading => _loading;
  String? get error => _error;
  List<MasterDataItem> get configuraciones => _configuraciones;
  List<MasterDataItem> get tiposCarroceria => _tiposCarroceria;
  List<MasterDataItem> get tiposIdentificacion => _tiposIdentificacion;
  bool get loadingMaestro => _loadingMaestro;
  String? get maestroError => _maestroError;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final rows = await SupabaseService.client
          .from('vehiculos')
          .select()
          .order('num_placa', ascending: true);

      _vehiculos = rows
          .map<VehiculoListItem>((r) => VehiculoListItem.fromMap(r))
          .toList();
    } catch (e) {
      debugPrint('Error loading vehiculos: $e');
      _vehiculos = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMaestro({
    required String rndcUsername,
    required String rndcPassword,
  }) async {
    _loadingMaestro = true;
    _maestroError = null;
    notifyListeners();
    try {
      final result = await ApiService.cargarMaestroVehiculos(
        rndcUsername: rndcUsername,
        rndcPassword: rndcPassword,
      );
      _configuraciones = result.configuracionesUnidadCarga;
      _tiposCarroceria = result.tiposCarroceria;
      _tiposIdentificacion = result.tiposIdentificacion;
      if (_configuraciones.isEmpty ||
          _tiposCarroceria.isEmpty ||
          _tiposIdentificacion.isEmpty) {
        _maestroError =
            'El backend no devolvio los catalogos RNDC. Intente actualizar o revise la API.';
      }
    } catch (e) {
      debugPrint('Error loading maestro vehiculos: $e');
      _maestroError = 'No fue posible cargar los catalogos RNDC: $e';
    }
    _loadingMaestro = false;
    notifyListeners();
  }

  Future<VehiculoRndcResult> registrar({
    required String rndcUsername,
    required String rndcPassword,
    required Vehiculo vehiculo,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.registrarVehiculo(
        rndcUsername: rndcUsername,
        rndcPassword: rndcPassword,
        vehiculo: vehiculo,
      );

      if (result.exito) {
        final toSave = Vehiculo(
          id: result.vehiculoId,
          numPlaca: vehiculo.numPlaca,
          codConfiguracionUnidadCarga: vehiculo.codConfiguracionUnidadCarga,
          pesoVehiculoVacio: vehiculo.pesoVehiculoVacio,
          codTipoCarroceria: vehiculo.codTipoCarroceria,
          codTipoIdTenedor: vehiculo.codTipoIdTenedor,
          numIdTenedor: vehiculo.numIdTenedor,
        );

        try {
          await SupabaseService.client.from('vehiculos').upsert({
            'id': result.vehiculoId,
            ...toSave.toInsertMap(),
            'estado': 'registered',
          });
        } catch (e) {
          debugPrint('Error saving vehiculo locally: $e');
        }

        await load();
        return result;
      } else {
        _error = result.error;
        notifyListeners();
        return result;
      }
    } catch (e) {
      _error = 'Error de conexión: $e';
      notifyListeners();
      return VehiculoRndcResult(exito: false, error: _error);
    }
  }

  Future<VehiculoRndcResult> registrarDirecto({
    required String rndcUsername,
    required String rndcPassword,
    required Vehiculo vehiculo,
  }) async {
    return registrar(
      rndcUsername: rndcUsername,
      rndcPassword: rndcPassword,
      vehiculo: vehiculo,
    );
  }
}
