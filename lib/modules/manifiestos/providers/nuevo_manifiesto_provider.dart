import 'package:flutter/foundation.dart';
import '../../../data/models/manifiesto.dart';
import '../../../services/api_service.dart';

class NuevoManifiestoProvider extends ChangeNotifier {
  int _step = 1;

  RemesaResumen? _remesaSeleccionada;
  bool _loadingRemesas = false;
  List<RemesaResumen> _remesasPendientes = [];

  String _placa = '';
  String _conductorCedula = '';
  double _valorViaje = 0;
  double _valorAnticipo = 0;
  String _tipoValorPactado = 'B';
  String _observaciones = '';
  bool _aceptacionElectronica = false;

  bool _submitting = false;
  String? _error;
  ManifiestoRndcResult? _resultado;
  bool _vehiculoNoRegistrado = false;

  int get step => _step;
  RemesaResumen? get remesaSeleccionada => _remesaSeleccionada;
  bool get loadingRemesas => _loadingRemesas;
  List<RemesaResumen> get remesasPendientes => _remesasPendientes;
  String get placa => _placa;
  String get conductorCedula => _conductorCedula;
  double get valorViaje => _valorViaje;
  double get valorAnticipo => _valorAnticipo;
  String get tipoValorPactado => _tipoValorPactado;
  String get observaciones => _observaciones;
  bool get aceptacionElectronica => _aceptacionElectronica;
  bool get submitting => _submitting;
  String? get error => _error;
  ManifiestoRndcResult? get resultado => _resultado;
  bool get vehiculoNoRegistrado => _vehiculoNoRegistrado;

  Future<void> loadRemesasPendientes(String token) async {
    _loadingRemesas = true;
    notifyListeners();
    try {
      _remesasPendientes = await ApiService.remesasPendientes(token);
    } catch (e) {
      debugPrint('Error loading remesas pendientes: $e');
      _remesasPendientes = [];
    }
    _loadingRemesas = false;
    notifyListeners();
  }

  void selectRemesa(RemesaResumen r) {
    _remesaSeleccionada = r;
    notifyListeners();
  }

  void preselectRemesa(RemesaResumen r) {
    _remesaSeleccionada = r;
    notifyListeners();
  }

  void updatePlaca(String v) {
    _placa = v;
    notifyListeners();
  }

  void updateConductorCedula(String v) {
    _conductorCedula = v;
    notifyListeners();
  }

  void updateValorViaje(double v) {
    _valorViaje = v;
    notifyListeners();
  }

  void updateValorAnticipo(double v) {
    _valorAnticipo = v;
    notifyListeners();
  }

  void updateTipoValorPactado(String v) {
    _tipoValorPactado = v;
    notifyListeners();
  }

  void updateObservaciones(String v) {
    _observaciones = v;
    notifyListeners();
  }

  void updateAceptacionElectronica(bool v) {
    _aceptacionElectronica = v;
    notifyListeners();
  }

  void clearVehiculoNoRegistrado() {
    _vehiculoNoRegistrado = false;
    notifyListeners();
  }

  void goToStep(int s) {
    _step = s;
    _error = null;
    notifyListeners();
  }

  Future<bool> generarManifiesto({
    required String rndcUsername,
    required String rndcPassword,
  }) async {
    if (_remesaSeleccionada == null) return false;
    if (_placa.isEmpty) {
      _error = 'Ingrese la placa del vehículo';
      notifyListeners();
      return false;
    }
    if (_conductorCedula.isEmpty) {
      _error = 'Ingrese la cédula del conductor';
      notifyListeners();
      return false;
    }

    _submitting = true;
    _error = null;
    notifyListeners();

    final manifiesto = Manifiesto(
      consecutivo: '',
      remesaId: _remesaSeleccionada!.id,
      placaVehiculo: _placa.toUpperCase(),
      conductorCedula: _conductorCedula,
      valorViaje: _valorViaje,
      valorAnticipo: _valorAnticipo,
      tipoValorPactado: _tipoValorPactado,
      observaciones: _observaciones.isEmpty ? null : _observaciones,
      aceptacionElectronica: _aceptacionElectronica ? 'SI' : null,
    );

    try {
      final resultado = await ApiService.generarManifiesto(
        rndcUsername: rndcUsername,
        rndcPassword: rndcPassword,
        manifiesto: manifiesto,
      );

      _resultado = resultado;

      if (resultado.vehiculoNoRegistrado) {
        _vehiculoNoRegistrado = true;
        _error = resultado.error;
        _submitting = false;
        notifyListeners();
        return false;
      }

      if (resultado.exito) {
        _submitting = false;
        _step = 3;
        notifyListeners();
        return true;
      } else {
        _error = resultado.error;
        _submitting = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error de conexión: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _step = 1;
    _remesaSeleccionada = null;
    _placa = '';
    _conductorCedula = '';
    _valorViaje = 0;
    _valorAnticipo = 0;
    _tipoValorPactado = 'B';
    _observaciones = '';
    _aceptacionElectronica = false;
    _submitting = false;
    _error = null;
    _resultado = null;
    _vehiculoNoRegistrado = false;
    notifyListeners();
  }
}
