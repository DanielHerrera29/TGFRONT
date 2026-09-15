import 'dart:convert';
import '../../core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class BorradorApiException implements Exception {
  final int status;
  BorradorApiException(this.status);
  @override
  String toString() => status == 400
      ? 'Datos rechazados. Corrija el borrador y vuelva a guardar.'
      : status == 409
      ? 'El borrador cambió. Puede recuperar la versión del servidor.'
      : 'No se pudo guardar ($status). Se conserva la operación para reintentar.';
}

/// Durable drafts keyed by user and order. No credentials are stored.
class BorradorOrden {
  final String userId;
  final SharedPreferences prefs;
  Map<String, dynamic> state;
  Future<void> _writes = Future.value();
  bool _saving = false;
  BorradorOrden._(this.userId, this.prefs, this.state);
  static const _base = ApiConfig.baseUrl;
  static Map<String, dynamic> _fresh() => {
    'clientOrderId': const Uuid().v4(),
    'version': 0,
  };
  static Future<BorradorOrden> load(
    String userId, {
    String? orderId,
    bool nueva = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString('orden_draft_v1_$userId');
    if (legacy != null) {
      final old = jsonDecode(legacy) as Map;
      final key = 'orden_draft_v2_${userId}_${old['clientOrderId']}';
      if (!prefs.containsKey(key)) await prefs.setString(key, legacy);
    }
    final raw = nueva
        ? null
        : orderId == null
        ? legacy
        : prefs.getString('orden_draft_v2_${userId}_$orderId');
    final draft = BorradorOrden._(
      userId,
      prefs,
      raw == null
          ? {..._fresh(), 'clientOrderId': ?orderId}
          : Map<String, dynamic>.from(jsonDecode(raw)),
    );
    return draft;
  }

  static Future<List<Map<String, dynamic>>> locales(String userId) async {
    await load(
      userId,
    ); // Migrate the previous single draft without deleting it.
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((k) => k.startsWith('orden_draft_v2_${userId}_'))
        .map((k) => Map<String, dynamic>.from(jsonDecode(prefs.getString(k)!)))
        .where((s) => s['fields'] != null && s['archived'] != true)
        .toList();
  }

  bool get pending => state['pending'] != null;
  bool get confirmed => (state['result'] as Map?)?['estado'] == 'CONFIRMADA';
  Future<void> persist() {
    final snapshot = jsonEncode(state);
    final key = 'orden_draft_v2_${userId}_${state['clientOrderId']}';
    // A failed write must not poison all subsequent retry attempts.
    _writes = _writes.catchError((_) {}).then((_) async {
      if (!await prefs.setString(key, snapshot) ||
          !await prefs.setString('orden_draft_v1_$userId', snapshot)) {
        throw StateError('No se pudo guardar el borrador local.');
      }
    });
    return _writes;
  }

  Future<void> capture(Map<String, dynamic> fields) async {
    if (pending || confirmed) return;
    state['fields'] = jsonDecode(jsonEncode(fields));
    await persist();
  }

  Future<Map<String, dynamic>> save(
    String token, {
    required bool confirmar,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? send,
  }) async {
    if (_saving) throw StateError('Ya hay un guardado en curso.');
    _saving = true;
    try {
      if (confirmed) return Map<String, dynamic>.from(state['result']);
      if (!pending) {
        state['pending'] = {
          'clave': const Uuid().v4(),
          'datos': {
            ...Map<String, dynamic>.from(state['fields'] ?? {}),
            'clientOrderId': state['clientOrderId'],
            'version': state['version'],
            'confirmar': confirmar,
          },
        };
      }
      // Persist identity and exact request before network; keep it on any error.
      await persist();
      final operation = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(state['pending'])),
      );
      Map<String, dynamic> result;
      try {
        result = await (send ?? (body) => _post(token, body))(operation);
      } on BorradorApiException catch (e) {
        // 400 is an explicit transactional rejection; a timeout/5xx is uncertain.
        if (e.status == 400) {
          state.remove('pending');
          await persist();
        }
        rethrow;
      }
      state['result'] = result;
      state['version'] = result['version'];
      state.remove('pending');
      await persist();
      return result;
    } finally {
      _saving = false;
    }
  }

  static Future<Map<String, dynamic>> _post(
    String token,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/servicios/orden-borrador'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw BorradorApiException(response.statusCode);
    }
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<void> finish() async {
    state['archived'] = true;
    await persist();
    state = _fresh();
    await persist();
  }

  /// Explicit user action. Keep the previous local version for recovery.
  Future<void> recover(
    String token, {
    Future<Map<String, dynamic>?> Function()? fetch,
  }) async {
    if (_saving) throw StateError('Espere a que termine el guardado.');
    final data =
        await (fetch ??
            () async {
              final r = await http
                  .get(
                    Uri.parse(
                      '$_base/api/servicios/orden-borrador/${state['clientOrderId']}',
                    ),
                    headers: {'Authorization': 'Bearer $token'},
                  )
                  .timeout(const Duration(seconds: 30));
              if (r.statusCode != 200) throw BorradorApiException(r.statusCode);
              final body = jsonDecode(r.body);
              return body == null ? null : Map<String, dynamic>.from(body);
            })();
    if (data == null) {
      throw StateError(
        'La orden aún no está en el servidor. Reintente el guardado pendiente.',
      );
    }
    if (!await prefs.setString(
      'orden_draft_backup_v1_$userId',
      jsonEncode(state),
    )) {
      throw StateError('No fue posible conservar la copia local.');
    }
    state = data;
    await persist();
  }

  static Future<List<Map<String, dynamic>>> clients(String token) async {
    final r = await http
        .get(
          Uri.parse('$_base/api/servicios/clientes'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw BorradorApiException(r.statusCode);
    return (jsonDecode(r.body) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> list(String token) async {
    final r = await http
        .get(
          Uri.parse('$_base/api/servicios'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw StateError('No se pudieron consultar los servicios.');
    }
    return (jsonDecode(r.body) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
