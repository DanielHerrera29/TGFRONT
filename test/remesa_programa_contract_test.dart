import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transportegutierrez/data/models/remesa.dart';
import 'package:transportegutierrez/services/api_service.dart';

void main() {
  test('programa capturado viaja a la API sin confundirse con obra', () async {
    final remesa = Remesa(
      consecutivo: '',
      generadorNit: 'fixture',
      remitenteNit: 'fixture',
      destinatarioNit: 'fixture',
      pesoKg: 18000,
      obra: 'Obra de prueba',
      programa: 'Programa de prueba',
    );
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['programa'], 'Programa de prueba');
      expect(body['obra'], 'Obra de prueba');
      return http.Response('{"exito":true,"remesa_id":"fixture"}', 200);
    });
    final result = await http.runWithClient(
      () => ApiService.generarRemesa(
        rndcUsername: 'fixture',
        rndcPassword: 'fixture',
        remesa: remesa,
      ),
      () => client,
    );
    expect(result.exito, isTrue);
    expect(
      Remesa.fromMap({
        'id': 'fixture',
        'peso_kg': 18000,
        'programa': 'Programa de prueba',
      }).programa,
      'Programa de prueba',
    );
  });
}
