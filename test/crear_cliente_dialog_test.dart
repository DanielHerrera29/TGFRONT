import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportegutierrez/data/models/cliente.dart';
import 'package:transportegutierrez/modules/clientes/crear_cliente_dialog.dart';

void main() {
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
