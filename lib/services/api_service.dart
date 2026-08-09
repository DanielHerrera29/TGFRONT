import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/models/remesa.dart';
import '../data/models/manifiesto.dart';
import '../data/models/vehiculo.dart';

class RemesaResumen {
  final String id;
  final String consecutivo;
  final String clienteNombre;
  final String estado;
  final double pesoKg;
  final DateTime createdAt;

  RemesaResumen.fromJson(Map<String, dynamic> j)
    : id = j['id']?.toString() ?? '',
      consecutivo = j['consecutivo']?.toString() ?? '',
      clienteNombre = j['cliente_nombre']?.toString() ?? '',
      estado = j['estado']?.toString() ?? '',
      pesoKg = (j['peso_kg'] ?? 0).toDouble(),
      createdAt = j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
          : DateTime.now();
}

class CumplirResult {
  final bool exito;
  final String? radicado;
  final String? error;
  CumplirResult({required this.exito, this.radicado, this.error});
}

class OrdenEscoltaCreada {
  final String id;
  final int consecutivo;
  const OrdenEscoltaCreada({required this.id, required this.consecutivo});
}

class OrdenEscoltaResumen {
  final String id;
  final int consecutivo;
  final DateTime fecha;
  final String empresa;
  final String placaCamabaja;
  final String? placaEscolta;
  final bool tienePdf;
  final DateTime? emailEnviadoAt;
  final String? emailError;

  OrdenEscoltaResumen.fromJson(Map<String, dynamic> json)
    : id = json['id']?.toString() ?? '',
      consecutivo = int.tryParse(json['consecutivo'].toString()) ?? 0,
      fecha =
          DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
      empresa = json['empresa']?.toString() ?? '',
      placaCamabaja = json['placa_camabaja']?.toString() ?? '',
      placaEscolta = json['placa_escolta']?.toString(),
      tienePdf = json['pdf_path'] != null,
      emailEnviadoAt = json['email_enviado_at'] == null
          ? null
          : DateTime.tryParse(json['email_enviado_at'].toString()),
      emailError = json['email_error']?.toString();
}

class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:5116',
  );

  static Future<String?> iniciarSesion(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/sesion/iniciar'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body)['token']?.toString();
  }

  static Future<void> guardarCorreoUsuario({
    required String token,
    required String usuarioId,
    required String correoEmail,
    required String contrasenaApp,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/usuarios/$usuarioId/correo'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'correoEmail': correoEmail,
            'contrasenaApp': contrasenaApp,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo guardar la configuración de correo');
    }
  }

  static Future<void> actualizarUsuario({
    required String token,
    required String usuarioId,
    required String name,
    required String email,
    String? password,
    required String role,
    required bool active,
    String? correoEmail,
    String? contrasenaApp,
  }) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/api/usuarios/$usuarioId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'role': role,
            'active': active,
            'correoEmail': correoEmail,
            'contrasenaApp': contrasenaApp,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo actualizar el usuario');
    }
  }

  static Future<OrdenEscoltaCreada> reservarOrdenEscolta({
    required String token,
    required DateTime fecha,
    required String empresa,
    required String placaCamabaja,
    required String placaEscolta,
    required String nombreEscolta,
    required String observaciones,
    required List<Map<String, String>> viajes,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/ordenes-escolta/reservar'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'fecha': fecha.toIso8601String().substring(0, 10),
            'empresa': empresa,
            'placaCamabaja': placaCamabaja,
            'placaEscolta': placaEscolta,
            'nombreEscolta': nombreEscolta,
            'observaciones': observaciones,
            'viajes': viajes,
          }),
        )
        .timeout(const Duration(seconds: 30));
    _ensureSuccess(response);
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return OrdenEscoltaCreada(
      id: data['id']?.toString() ?? '',
      consecutivo: int.tryParse(data['consecutivo'].toString()) ?? 0,
    );
  }

  static Future<void> enviarOrdenEscolta({
    required String token,
    required String ordenId,
    required List<int> pdf,
  }) async {
    final response = await http
        .post(
          Uri.parse(
            '$_baseUrl/api/ordenes-escolta/${Uri.encodeComponent(ordenId)}/enviar',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'pdfBase64': base64Encode(pdf)}),
        )
        // Render Free puede tardar cerca de un minuto en despertar antes de
        // que la API suba el PDF y contacte el servidor de correo.
        .timeout(const Duration(seconds: 150));
    _ensureSuccess(response);
  }

  static Future<List<OrdenEscoltaResumen>> listarOrdenesEscolta(
    String token,
  ) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/api/ordenes-escolta'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map(
          (item) => OrdenEscoltaResumen.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static Future<Uri> urlPdfOrdenEscolta({
    required String token,
    required String ordenId,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '$_baseUrl/api/ordenes-escolta/${Uri.encodeComponent(ordenId)}/pdf',
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    _ensureSuccess(response);
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final url = data['url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('No se recibio la URL del PDF');
    }
    return Uri.parse(url);
  }

  static Future<List<Map<String, dynamic>>> listarRemesas() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/remesa'))
        .timeout(const Duration(seconds: 30));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> obtenerRemesa(String id) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/remesa/${Uri.encodeComponent(id)}'))
        .timeout(const Duration(seconds: 30));
    _ensureSuccess(response);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> listarManifiestos() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/manifiesto'))
        .timeout(const Duration(seconds: 30));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> obtenerManifiesto(String id) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/manifiesto/${Uri.encodeComponent(id)}'))
        .timeout(const Duration(seconds: 30));
    _ensureSuccess(response);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(
      'API ${response.statusCode}: ${response.body.isEmpty ? 'sin respuesta' : response.body}',
    );
  }

  static Future<RemesaRndcResult> generarRemesa({
    required String rndcUsername,
    required String rndcPassword,
    required Remesa remesa,
  }) async {
    final body = {
      'rndcUsername': rndcUsername,
      'rndcPassword': rndcPassword,
      'tipoOperacion': remesa.tipoOperacion,
      'naturalezaCarga': remesa.naturalezaCarga,
      'cantidad': remesa.cantidad,
      'unidadMedida': remesa.unidadMedida,
      'tipoEmpaque': remesa.tipoEmpaque,
      'pesoKg': remesa.pesoKg,
      'codigoProducto': remesa.codigoProducto,
      'descripcionProducto': remesa.descripcionProducto,
      'generadorTipoId': remesa.generadorTipoId,
      'generadorNit': remesa.generadorNit,
      'generadorSede': remesa.generadorSede,
      'remitenteTipoId': remesa.remitenteTipoId,
      'remitenteNit': remesa.remitenteNit,
      'remitenteSede': remesa.remitenteSede,
      'remitenteMunicipioDane': remesa.remitenteMunicipioDane,
      'propietarioTipoId': remesa.generadorTipoId,
      'propietarioNit': remesa.generadorNit,
      'propietarioSede': remesa.generadorSede,
      'destinatarioTipoId': remesa.destinatarioTipoId,
      'destinatarioNit': remesa.destinatarioNit,
      'destinatarioSede': remesa.destinatarioSede,
      'destinatarioMunicipioDane': remesa.destinatarioMunicipioDane,
      'polizaNumero': remesa.polizaNumero,
      'polizaVencimiento': remesa.polizaVencimiento?.toIso8601String(),
      'polizaAseguradora': remesa.polizaAseguradora,
      'polizaAseguradoraNit': remesa.polizaAseguradoraNit,
      'fechaCitaCargue': remesa.fechaCargue,
      'horaCitaCargue': remesa.horaCargue,
      'rawMessage': remesa.rawMessage,
      'clienteNombre': remesa.clienteNombre,
      'obra': remesa.obra,
      'observaciones': remesa.observaciones,
    };

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/remesa/generar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      final data = jsonDecode(response.body);

      return RemesaRndcResult(
        exito: data['exito'] ?? false,
        remesaId: data['remesa_id'],
        consecutivo: data['consecutivo'],
        radicadoRndc: data['radicado_rndc'],
        xmlEnviado: data['xml_enviado'],
        error: data['error'],
        codigoError: data['codigo_error'],
      );
    } catch (e) {
      return RemesaRndcResult(
        exito: false,
        error: 'Error de conexión con la API: $e',
      );
    }
  }

  static Future<List<RemesaResumen>> remesasPendientes(String token) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/api/remesa/pendientes'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 30));

    final List data = jsonDecode(response.body);
    return data.map((j) => RemesaResumen.fromJson(j)).toList();
  }

  static Future<CumplirResult> cumplirRemesa({
    required String rndcUsername,
    required String rndcPassword,
    required String remesaId,
    required String tipocumplido,
    String? observaciones,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/remesa/cumplir'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'rndcUsername': rndcUsername,
            'rndcPassword': rndcPassword,
            'remesaId': remesaId,
            'tipoCumplido': tipocumplido,
            'observaciones': observaciones ?? 'NINGUNA',
          }),
        )
        .timeout(const Duration(seconds: 60));

    final data = jsonDecode(response.body);
    return CumplirResult(
      exito: data['exito'] ?? false,
      radicado: data['radicado'],
      error: data['error'],
    );
  }

  static Future<CumplirResult> cumplirManifiesto({
    required String rndcUsername,
    required String rndcPassword,
    required String manifiestoId,
    required String tipoCumplido,
    String? observaciones,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/manifiesto/cumplir'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'rndcUsername': rndcUsername,
            'rndcPassword': rndcPassword,
            'manifiestoId': manifiestoId,
            'tipoCumplido': tipoCumplido,
            'observaciones': observaciones ?? 'NINGUNA',
          }),
        )
        .timeout(const Duration(seconds: 60));

    final data = jsonDecode(response.body);
    return CumplirResult(
      exito: data['exito'] ?? false,
      radicado: data['radicado'],
      error: data['error'],
    );
  }

  static Future<ManifiestoRndcResult> generarManifiesto({
    required String rndcUsername,
    required String rndcPassword,
    required Manifiesto manifiesto,
  }) async {
    final body = {
      'rndcUsername': rndcUsername,
      'rndcPassword': rndcPassword,
      'remesaId': manifiesto.remesaId,
      'placaVehiculo': manifiesto.placaVehiculo,
      'placaRemolque': manifiesto.placaRemolque,
      'conductorTipoId': manifiesto.conductorTipoId,
      'conductorCedula': manifiesto.conductorCedula,
      'conductor2Cedula': manifiesto.conductor2Cedula,
      'propietarioTipoId': manifiesto.propietarioTipoId,
      'propietarioCedula': manifiesto.propietarioCedula,
      'fechaDespacho': manifiesto.fechaDespacho?.toIso8601String(),
      'fechaLimiteEntrega': manifiesto.fechaLimiteEntrega?.toIso8601String(),
      'tipoValorPactado': manifiesto.tipoValorPactado,
      'valorViaje': manifiesto.valorViaje,
      'valorAnticipo': manifiesto.valorAnticipo,
      'municipioPagoDane': manifiesto.municipioPagoDane,
      'fechaLimitePago': manifiesto.fechaLimitePago?.toIso8601String(),
      'respCargue': manifiesto.respCargue,
      'respDescargue': manifiesto.respDescargue,
      'horasEsperaCargue': manifiesto.horasEsperaCargue,
      'horasEsperaDescargue': manifiesto.horasEsperaDescargue,
      'observaciones': manifiesto.observaciones,
      if (manifiesto.aceptacionElectronica != null)
        'aceptacionElectronica': manifiesto.aceptacionElectronica,
    };

    try {
      debugPrint('Manifiesto payload: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/manifiesto/generar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      final data = jsonDecode(response.body);

      if (data['vehiculo_no_registrado'] == true) {
        return ManifiestoRndcResult(
          exito: false,
          vehiculoNoRegistrado: true,
          error: data['error'] ?? 'Vehículo no registrado en RNDC',
        );
      }

      return ManifiestoRndcResult(
        exito: data['exito'] ?? false,
        manifiestoId: data['manifiesto_id'],
        consecutivo: data['consecutivo'],
        numeroAutorizacion: data['numero_autorizacion'],
        xmlEnviado: data['xml_enviado'],
        error: data['error'],
        codigoError: data['codigo_error'],
      );
    } catch (e) {
      return ManifiestoRndcResult(
        exito: false,
        error: 'Error de conexión con la API: $e',
      );
    }
  }

  static Future<VehiculoRndcResult> registrarVehiculo({
    required String rndcUsername,
    required String rndcPassword,
    required Vehiculo vehiculo,
  }) async {
    final body = {
      'rndcUsername': rndcUsername,
      'rndcPassword': rndcPassword,
      'numPlaca': vehiculo.numPlaca,
      'codConfiguracionUnidadCarga': vehiculo.codConfiguracionUnidadCarga,
      'pesoVehiculoVacio': vehiculo.pesoVehiculoVacio,
      'codTipoCarroceria': vehiculo.codTipoCarroceria,
      'codTipoIdTenedor': vehiculo.codTipoIdTenedor,
      'numIdTenedor': vehiculo.numIdTenedor,
    };

    try {
      debugPrint(
        'Registro vehiculo RNDC: placa=${vehiculo.numPlaca}, '
        'configuracion=${vehiculo.codConfiguracionUnidadCarga}, '
        'carroceria=${vehiculo.codTipoCarroceria}, '
        'tipoTenedor=${vehiculo.codTipoIdTenedor}, '
        'tenedor=${vehiculo.numIdTenedor}',
      );
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/rndc/vehiculos'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint(
        'Respuesta registro vehiculo: ${response.statusCode} ${response.body}',
      );
      final data = jsonDecode(response.body);
      return VehiculoRndcResult(
        exito: data['exito'] ?? false,
        vehiculoId: data['vehiculo_id'],
        error: data['error'],
      );
    } catch (e) {
      return VehiculoRndcResult(
        exito: false,
        error: 'Error de conexión con la API: $e',
      );
    }
  }

  static Future<ManifiestoFirmaStatus> consultarFirmaManifiesto({
    required String rndcUsername,
    required String rndcPassword,
    required String manifiestoId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/rndc/manifiestos/firma-status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'rndcUsername': rndcUsername,
              'rndcPassword': rndcPassword,
              'manifiestoId': manifiestoId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      return ManifiestoFirmaStatus.fromMap(data);
    } catch (e) {
      return ManifiestoFirmaStatus(
        estado: 'desconocido',
        error: 'Error consultando estado de firma: $e',
      );
    }
  }

  static Future<List<PendienteFirmaItem>> pendientesDeFirma({
    required String rndcUsername,
    required String rndcPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/rndc/manifiestos/pendientes-firma'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'rndcUsername': rndcUsername,
              'rndcPassword': rndcPassword,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final List data = jsonDecode(response.body);
      return data.map((j) => PendienteFirmaItem.fromMap(j)).toList();
    } catch (e) {
      debugPrint('Error loading pendientes de firma: $e');
      return [];
    }
  }

  static Future<MasterDataResult> cargarMaestroVehiculos({
    required String rndcUsername,
    required String rndcPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/rndc/vehiculos/maestro'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'rndcUsername': rndcUsername,
              'rndcPassword': rndcPassword,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      return MasterDataResult.fromMap(data);
    } catch (e) {
      return MasterDataResult();
    }
  }
}

class RemesaRndcResult {
  final bool exito;
  final String? remesaId;
  final String? consecutivo;
  final String? radicadoRndc;
  final String? xmlEnviado;
  final String? error;
  final String? codigoError;

  RemesaRndcResult({
    required this.exito,
    this.remesaId,
    this.consecutivo,
    this.radicadoRndc,
    this.xmlEnviado,
    this.error,
    this.codigoError,
  });
}

class ManifiestoRndcResult {
  final bool exito;
  final String? manifiestoId;
  final String? consecutivo;
  final String? numeroAutorizacion;
  final String? xmlEnviado;
  final String? error;
  final String? codigoError;
  final bool vehiculoNoRegistrado;

  ManifiestoRndcResult({
    required this.exito,
    this.manifiestoId,
    this.consecutivo,
    this.numeroAutorizacion,
    this.xmlEnviado,
    this.error,
    this.codigoError,
    this.vehiculoNoRegistrado = false,
  });
}

class VehiculoRndcResult {
  final bool exito;
  final String? vehiculoId;
  final String? error;
  VehiculoRndcResult({required this.exito, this.vehiculoId, this.error});
}

class ManifiestoFirmaStatus {
  final String estado;
  final DateTime? firmaConductor;
  final DateTime? firmaTitular;
  final String? error;

  ManifiestoFirmaStatus({
    required this.estado,
    this.firmaConductor,
    this.firmaTitular,
    this.error,
  });

  bool get estaCompleto => estado == 'completo';
  bool get faltaConductor =>
      estado == 'pendiente_conductor' || estado == 'pendiente_ambos';
  bool get faltaTitular =>
      estado == 'pendiente_titular' || estado == 'pendiente_ambos';

  String get resumenFalta {
    if (estaCompleto) return '';
    if (faltaConductor && faltaTitular) {
      return 'Falta firma del Conductor y del Titular';
    }
    if (faltaConductor) return 'Falta firma del Conductor';
    if (faltaTitular) return 'Falta firma del Titular';
    return '';
  }

  factory ManifiestoFirmaStatus.fromMap(Map<String, dynamic> j) =>
      ManifiestoFirmaStatus(
        estado: j['estado']?.toString() ?? 'desconocido',
        firmaConductor: j['firma_conductor'] != null
            ? DateTime.tryParse(j['firma_conductor'].toString())
            : null,
        firmaTitular: j['firma_titular'] != null
            ? DateTime.tryParse(j['firma_titular'].toString())
            : null,
        error: j['error']?.toString(),
      );
}

class PendienteFirmaItem {
  final String manifiestoId;
  final String consecutivo;
  final String? titularNombre;
  final String? placa;
  final String? conductorNombre;
  final DateTime? fechaExpedicion;

  PendienteFirmaItem({
    required this.manifiestoId,
    required this.consecutivo,
    this.titularNombre,
    this.placa,
    this.conductorNombre,
    this.fechaExpedicion,
  });

  factory PendienteFirmaItem.fromMap(Map<String, dynamic> j) =>
      PendienteFirmaItem(
        manifiestoId: j['manifiesto_id']?.toString() ?? '',
        consecutivo: j['consecutivo']?.toString() ?? '',
        titularNombre: j['titular_nombre']?.toString(),
        placa: j['placa']?.toString(),
        conductorNombre: j['conductor_nombre']?.toString(),
        fechaExpedicion: j['fecha_expedicion'] != null
            ? DateTime.tryParse(j['fecha_expedicion'].toString())
            : null,
      );
}

class MasterDataResult {
  final List<MasterDataItem> configuracionesUnidadCarga;
  final List<MasterDataItem> tiposCarroceria;
  final List<MasterDataItem> tiposIdentificacion;

  MasterDataResult({
    this.configuracionesUnidadCarga = const [],
    this.tiposCarroceria = const [],
    this.tiposIdentificacion = const [],
  });

  factory MasterDataResult.fromMap(Map<String, dynamic> j) => MasterDataResult(
    configuracionesUnidadCarga:
        (j['configuraciones_unidad_carga'] as List?)
            ?.map((e) => MasterDataItem.fromMap(e))
            .toList() ??
        [],
    tiposCarroceria:
        (j['tipos_carroceria'] as List?)
            ?.map((e) => MasterDataItem.fromMap(e))
            .toList() ??
        [],
    tiposIdentificacion:
        (j['tipos_identificacion'] as List?)
            ?.map((e) => MasterDataItem.fromMap(e))
            .toList() ??
        [],
  );
}

class MasterDataItem {
  final String codigo;
  final String nombre;

  MasterDataItem({required this.codigo, required this.nombre});

  factory MasterDataItem.fromMap(Map<String, dynamic> j) => MasterDataItem(
    codigo: j['codigo']?.toString() ?? '',
    nombre: j['nombre']?.toString() ?? '',
  );
}
