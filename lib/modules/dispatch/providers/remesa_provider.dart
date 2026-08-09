import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../../../data/datasource/local_store.dart';
import '../../../data/models/remesa.dart';
import '../../../core/utils/message_parser.dart';
import '../../../services/api_service.dart';
import '../../settings/providers/settings_provider.dart';

class RemesaProvider extends ChangeNotifier {
  final LocalStore _store;
  final MessageParser _parser = MessageParser();

  RemesaProvider(this._store);

  String _rawMessage = '';
  Remesa? _remesaActual;
  bool _processing = false;
  bool _saving = false;
  bool _loading = false;
  String? _error;
  RemesaRndcResult? _ultimoResultado;

  String get rawMessage => _rawMessage;
  Remesa? get remesaActual => _remesaActual;
  bool get processing => _processing;
  bool get saving => _saving;
  bool get loading => _loading;
  String? get error => _error;
  RemesaRndcResult? get ultimoResultado => _ultimoResultado;

  void setRawMessage(String text) {
    _rawMessage = text;
    notifyListeners();
  }

  Future<void> parse(SettingsProvider settingsProvider) async {
    _processing = true;
    _error = null;
    notifyListeners();

    var settings = _store.settings;
    if (settings == null) {
      await settingsProvider.load();
      settings = _store.settings;
    }

    _remesaActual = _parser.parseToRemesa(_rawMessage, settings);
    _processing = false;
    notifyListeners();
  }

  void setDestinatarioNit(String destinatarioNit) {
    if (_remesaActual == null) return;
    _remesaActual = _remesaActual!.copyWith(
      destinatarioNit: destinatarioNit,
      destinatarioSede: '00',
    );
    notifyListeners();
  }

  void setDestinatarioMunicipioDane(String municipioDane) {
    if (_remesaActual == null) return;
    final codigoRncd = municipioDane.length == 5
        ? '${municipioDane}000'
        : municipioDane;
    _remesaActual = _remesaActual!.copyWith(
      destinatarioMunicipioDane: codigoRncd,
    );
    notifyListeners();
  }

  void clear() {
    _rawMessage = '';
    _remesaActual = null;
    _error = null;
    _ultimoResultado = null;
    notifyListeners();
  }

  Future<bool> saveRemesa() async {
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      String consecutivo;
      try {
        consecutivo = await SupabaseService.client.rpc(
          'generar_consecutivo_remesa',
        );
      } catch (_) {
        consecutivo = 'TEMP-${DateTime.now().millisecondsSinceEpoch}';
      }

      final data = _remesaActual!;
      final remesa = Remesa(
        consecutivo: consecutivo,
        generadorTipoId: data.generadorTipoId,
        generadorNit: data.generadorNit,
        generadorDv: data.generadorDv,
        generadorNombre: data.generadorNombre,
        generadorSede: data.generadorSede,
        remitenteTipoId: data.remitenteTipoId,
        remitenteNit: data.remitenteNit,
        remitenteNombre: data.remitenteNombre,
        remitenteSede: data.remitenteSede,
        remitenteDireccion: data.remitenteDireccion,
        remitenteMunicipioDane: data.remitenteMunicipioDane,
        destinatarioTipoId: data.destinatarioTipoId,
        destinatarioNit: data.destinatarioNit,
        destinatarioNombre: data.destinatarioNombre,
        destinatarioSede: data.destinatarioSede,
        destinatarioDireccion: data.destinatarioDireccion,
        destinatarioMunicipioDane: data.destinatarioMunicipioDane,
        naturalezaCarga: data.naturalezaCarga,
        codigoProducto: data.codigoProducto,
        descripcionProducto: data.descripcionProducto,
        tipoEmpaque: data.tipoEmpaque,
        cantidad: data.cantidad,
        unidadMedida: data.unidadMedida,
        pesoKg: data.pesoKg,
        tipoOperacion: data.tipoOperacion,
        valorMercancia: data.valorMercancia,
        valorFlete: data.valorFlete,
        polizaNumero: data.polizaNumero,
        polizaVencimiento: data.polizaVencimiento,
        polizaAseguradora: data.polizaAseguradora,
        polizaAseguradoraNit: data.polizaAseguradoraNit,
        rawMessage: _rawMessage,
        clienteNombre: data.clienteNombre,
        obra: data.obra,
        programa: data.programa,
        observaciones: data.observaciones,
        estado: 'draft',
        createdBy: _store.currentUser?.id,
      );

      final row = await SupabaseService.insert('remesas', remesa.toInsertMap());
      final saved = Remesa.fromMap(row);
      _remesaActual = saved;
      _rawMessage = '';
      _saving = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving remesa: $e');
      _error = 'Error al guardar remesa';
      _saving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> enviarARndc({
    required String rndcUsername,
    required String rndcPassword,
  }) async {
    if (_remesaActual == null) return false;

    final settings = _store.settings;
    final fallbackNit = settings?.generadorNit ?? settings?.empresaNit ?? '';
    if (fallbackNit.isNotEmpty &&
        (_remesaActual!.generadorNit.isEmpty ||
            _remesaActual!.remitenteNit.isEmpty)) {
      _remesaActual = _remesaActual!.copyWith(
        generadorNit: _remesaActual!.generadorNit.isEmpty ? fallbackNit : null,
        remitenteNit: _remesaActual!.remitenteNit.isEmpty ? fallbackNit : null,
      );
    }

    debugPrint('=== Remesa antes de enviarARndc ===');
    debugPrint('remitenteNit: "${_remesaActual!.remitenteNit}"');
    debugPrint('destinatarioNit: "${_remesaActual!.destinatarioNit}"');
    debugPrint('remitenteSede: "${_remesaActual!.remitenteSede}"');
    debugPrint('destinatarioSede: "${_remesaActual!.destinatarioSede}"');
    debugPrint('===================================');

    _loading = true;
    _error = null;
    _ultimoResultado = null;
    notifyListeners();

    final resultado = await ApiService.generarRemesa(
      rndcUsername: rndcUsername,
      rndcPassword: rndcPassword,
      remesa: _remesaActual!,
    );

    _ultimoResultado = resultado;

    if (resultado.exito) {
      _remesaActual = _remesaActual!.copyWith(
        id: resultado.remesaId,
        estado: 'generated',
        radicadoRndc: resultado.radicadoRndc,
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
