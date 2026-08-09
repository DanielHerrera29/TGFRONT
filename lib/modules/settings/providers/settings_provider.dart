import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../../../data/datasource/local_store.dart';
import '../../../data/models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  final LocalStore _store;

  SettingsProvider(this._store);

  bool _loading = false;

  AppSettings? get settings => _store.settings;
  bool get loading => _loading;
  bool get simulation => _store.settings?.esModoSimulacion ?? true;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      final rows = await SupabaseService.client
          .from('settings')
          .select()
          .limit(1);
      if (rows.isNotEmpty) {
        _store.setSettings(AppSettings.fromMap(rows.first));
      }
    } catch (_) {}

    _loading = false;
    notifyListeners();
  }

  Future<void> saveAll({
    String? empresaNombre,
    required String empresaNit,
    String? empresaDv,
    String? empresaDireccion,
    String? empresaTelefono,
    String? empresaCiudad,
    required String empresaMunicipioDane,
    String? generadorNit,
    String? generadorDv,
    String? generadorNombre,
    required String generadorSede,
    String? polizaNumero,
    DateTime? polizaVencimiento,
    String? polizaAseguradora,
    String? polizaAseguradoraNit,
    required String simulacion,
  }) async {
    try {
      final rows = await SupabaseService.client
          .from('settings')
          .select('id')
          .limit(1);
      if (rows.isEmpty) return;

      final id = rows.first['id'];
      final data = {
        'empresa_nombre': empresaNombre,
        'empresa_nit': empresaNit,
        'empresa_dv': empresaDv,
        'empresa_direccion': empresaDireccion,
        'empresa_telefono': empresaTelefono,
        'empresa_ciudad': empresaCiudad,
        'empresa_municipio_dane': empresaMunicipioDane,
        'generador_tipo_id': 'N',
        'generador_nit': generadorNit,
        'generador_dv': generadorDv,
        'generador_nombre': generadorNombre,
        'generador_sede': generadorSede,
        'poliza_numero': polizaNumero,
        'poliza_vencimiento': polizaVencimiento?.toIso8601String(),
        'poliza_aseguradora': polizaAseguradora,
        'poliza_aseguradora_nit': polizaAseguradoraNit,
        'simulacion': simulacion,
      };

      await SupabaseService.client.from('settings').update(data).eq('id', id);

      _store.setSettings(
        AppSettings(
          id: id.toString(),
          empresaNombre: empresaNombre,
          empresaNit: empresaNit,
          empresaDv: empresaDv,
          empresaDireccion: empresaDireccion,
          empresaTelefono: empresaTelefono,
          empresaCiudad: empresaCiudad,
          empresaMunicipioDane: empresaMunicipioDane,
          generadorTipoId: 'N',
          generadorNit: generadorNit,
          generadorDv: generadorDv,
          generadorNombre: generadorNombre,
          generadorSede: generadorSede,
          polizaNumero: polizaNumero,
          polizaVencimiento: polizaVencimiento,
          polizaAseguradora: polizaAseguradora,
          polizaAseguradoraNit: polizaAseguradoraNit,
          simulacion: simulacion,
          consecutivoRemesa: _store.settings?.consecutivoRemesa ?? 1,
          consecutivoManifiesto: _store.settings?.consecutivoManifiesto ?? 1,
        ),
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> toggleSimulation(bool value) async {
    final s = _store.settings;
    if (s == null) return;
    await saveAll(
      empresaNombre: s.empresaNombre,
      empresaNit: s.empresaNit,
      empresaDv: s.empresaDv,
      empresaDireccion: s.empresaDireccion,
      empresaTelefono: s.empresaTelefono,
      empresaCiudad: s.empresaCiudad,
      empresaMunicipioDane: s.empresaMunicipioDane,
      generadorNit: s.generadorNit,
      generadorDv: s.generadorDv,
      generadorNombre: s.generadorNombre,
      generadorSede: s.generadorSede,
      polizaNumero: s.polizaNumero,
      polizaVencimiento: s.polizaVencimiento,
      polizaAseguradora: s.polizaAseguradora,
      polizaAseguradoraNit: s.polizaAseguradoraNit,
      simulacion: value ? 'S' : 'R',
    );
  }
}
