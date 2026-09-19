import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../data/models/cliente.dart';

class ClienteRechazado implements Exception {
  final String mensaje;
  ClienteRechazado(this.mensaje);
  @override
  String toString() => mensaje;
}

class ClientesApi {
  static Future<List<Map<String, dynamic>>> vehiculos(String token) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/servicios/clientes/vehiculos-disponibles',
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('No se pudieron cargar los vehículos registrados.');
    }
    return (jsonDecode(response.body) as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  static Future<void> vincular(
    String token,
    String cliente,
    String vehiculo,
  ) async {
    final response = await http
        .put(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/servicios/clientes/$cliente/vehiculos/$vehiculo',
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw StateError(
        'No se pudo vincular el vehículo. Puede reintentar sin duplicarlo.',
      );
    }
  }

  static Future<Cliente> crear(String token, Map<String, dynamic> datos) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/servicios/clientes'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(datos),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      if (response.statusCode == 400 ||
          response.statusCode == 403 ||
          response.statusCode == 409) {
        throw ClienteRechazado(
          response.statusCode == 403
              ? 'Solo administración puede crear clientes y agregar placas.'
              : 'Revise los datos. El documento puede estar registrado; busque la empresa en el listado para agregarle placas.',
        );
      }
      throw StateError(
        response.statusCode == 409
            ? 'El documento o la solicitud ya existen. Cierre y actualice el listado para seleccionar el cliente.'
            : response.statusCode == 403
            ? 'Su usuario no tiene permiso para crear clientes.'
            : 'No se pudo registrar el cliente. Reintente o actualice el listado antes de crear otro.',
      );
    }
    return Cliente.fromMap(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }
}
