import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';

class FirmaProvider extends ChangeNotifier {
  ManifiestoFirmaStatus? _status;
  bool _loading = false;
  String? _error;

  List<PendienteFirmaItem> _pendientes = [];
  bool _loadingPendientes = false;

  ManifiestoFirmaStatus? get status => _status;
  bool get loading => _loading;
  String? get error => _error;
  List<PendienteFirmaItem> get pendientes => _pendientes;
  bool get loadingPendientes => _loadingPendientes;

  Future<void> consultarFirma({
    required String rndcUsername,
    required String rndcPassword,
    required String manifiestoId,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _status = await ApiService.consultarFirmaManifiesto(
        rndcUsername: rndcUsername,
        rndcPassword: rndcPassword,
        manifiestoId: manifiestoId,
      );

      if (_status!.error != null) {
        _error = _status!.error;
      }
    } catch (e) {
      _error = 'Error consultando firma: $e';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> loadPendientes({
    required String rndcUsername,
    required String rndcPassword,
  }) async {
    _loadingPendientes = true;
    notifyListeners();

    try {
      _pendientes = await ApiService.pendientesDeFirma(
        rndcUsername: rndcUsername,
        rndcPassword: rndcPassword,
      );
    } catch (e) {
      debugPrint('Error loading pendientes de firma: $e');
      _pendientes = [];
    }

    _loadingPendientes = false;
    notifyListeners();
  }

  void clearStatus() {
    _status = null;
    _error = null;
    notifyListeners();
  }
}
