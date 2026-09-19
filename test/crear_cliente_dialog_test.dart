import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportegutierrez/data/models/cliente.dart';
import 'package:transportegutierrez/modules/clientes/crear_cliente_dialog.dart';

void main() {
  testWidgets(
    'agregar placas a empresa existente conserva identidad ante timeout',
    (tester) async {
      Map<String, dynamic>? solicitud;
      var llamadas = 0;
      final c = Cliente.fromMap({
        'id': 'existente',
        'nombre': 'Empresa',
        'nit_o_documento': '900123456',
        'placas_carga': ['ABC123'],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrearClienteDialog(
              token: 'fixture',
              cliente: c,
              crear: (datos) async {
                llamadas++;
                if (llamadas == 1) {
                  solicitud = datos;
                  throw TimeoutException('respuesta perdida');
                }
                expect(datos, solicitud);
                expect(datos['id'], 'existente');
                expect(datos['placas'], ['ABC123', 'MNB124']);
                return c;
              },
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('placa-cliente')),
        'abc123',
      );
      await tester.ensureVisible(find.text('Agregar placa'));
      await tester.tap(find.text('Agregar placa'));
      await tester.pump();
      expect(find.text('Esta placa ya está agregada.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('placa-cliente')),
        'mnb124',
      );
      await tester.tap(find.text('Guardar placas'));
      await tester.pumpAndSettle();
      expect(llamadas, 1);
      await tester.tap(find.text('Guardar placas'));
      await tester.pumpAndSettle();
      expect(llamadas, 2);
      expect(tester.takeException(), isNull);
    },
  );
  test('la placa directa del cliente se recupera para una nueva orden', () {
    final cliente = Cliente.fromMap({
      'id': 'fixture',
      'nombre': 'Cliente',
      'placa_carga': 'XYZ987',
      'placas_carga': ['XYZ987', 'ABC123'],
      'cliente_vehiculos': [],
    });
    expect(cliente.placasCarga, ['XYZ987', 'ABC123']);
  });
  testWidgets(
    'cliente valida campos y bloquea doble envío en pantalla compacta',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final completer = Completer<Cliente>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<Cliente>(
                  context: context,
                  builder: (_) => CrearClienteDialog(
                    token: 'fake',
                    crear: (datos) {
                      calls++;
                      expect(datos['nombre'], 'Empresa prueba');
                      expect(datos['placas'], ['ABC123', 'MNB124']);
                      return completer.future;
                    },
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear cliente'));
      await tester.pump();
      expect(calls, 0);
      expect(find.text('Ingrese el nombre'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Empresa prueba',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '900123456');
      await tester.enterText(
        find.byKey(const ValueKey('placa-cliente')),
        'abc123',
      );
      await tester.ensureVisible(find.text('Agregar placa'));
      await tester.tap(find.text('Agregar placa'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('placa-cliente')),
        'MNB124',
      );
      await tester.tap(find.text('Crear cliente'));
      await tester.pump();
      await tester.tap(find.text('Guardando…'));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      completer.complete(
        Cliente.fromMap({'id': 'cliente', 'nombre': 'Empresa prueba'}),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CrearClienteDialog), findsNothing);
    },
  );
}
