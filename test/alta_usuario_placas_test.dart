import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportegutierrez/modules/auth/screens/register_user_screen.dart';
import 'package:transportegutierrez/services/api_service.dart';

void main() {
  test(
    'código de placa prevalece y documentos históricos conservan número',
    () {
      expect(
        const OrdenEscoltaCreada(
          id: 'x',
          consecutivo: 89,
          codigoOrden: 'C123-1',
        ).numeroVisible,
        'C123-1',
      );
      expect(
        const OrdenEscoltaCreada(id: 'x', consecutivo: 36).numeroVisible,
        '00036',
      );
      expect(
        OrdenEscoltaResumen.fromJson({
          'id': 'x',
          'consecutivo': 89,
          'codigo_orden': 'C123-1',
        }).numeroVisible,
        'C123-1',
      );
    },
  );

  for (final enlazar in [false, true]) {
    testWidgets(
      'alta opcional de placas: $enlazar, reintento sin cambiar identidad',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <Map<String, dynamic>>[];
        final response = Completer<String>();
        await tester.pumpWidget(
          MaterialApp(
            home: RegisterUserScreen(
              crearUsuario: (data) {
                requests.add(Map.from(data));
                return response.future;
              },
            ),
          ),
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Escolta de prueba');
        await tester.enterText(fields.at(1), '3144672648');
        await tester.enterText(fields.at(2), 'fixture@example.com');
        await tester.enterText(fields.at(3), 'fixture-only');
        await tester.enterText(fields.at(4), 'fixture-only');
        if (enlazar) {
          await tester.ensureVisible(find.byType(SwitchListTile));
          await tester.tap(find.byType(SwitchListTile));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('placa-usuario')),
          );
          await tester.enterText(
            find.byKey(const ValueKey('placa-usuario')),
            'xyz987',
          );
          await tester.tap(find.text('Agregar placa'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('placa-usuario')),
            'XYZ987',
          );
          await tester.tap(find.text('Agregar placa'));
          await tester.pumpAndSettle();
          expect(find.text('Esta placa ya está agregada.'), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey('placa-usuario')),
            'mnb124',
          );
          await tester.tap(find.text('Agregar placa'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Crear usuario'));
        await tester.tap(find.text('Crear usuario'));
        await tester.tap(find.text('Crear usuario'));
        await tester.pump();
        expect(requests.length, 1);
        expect(
          requests.single['placas'],
          enlazar ? ['XYZ987', 'MNB124'] : isEmpty,
        );
        response.completeError(TimeoutException('fixture'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Crear usuario'));
        await tester.tap(find.text('Crear usuario'));
        await tester.pumpAndSettle();
        expect(requests.length, 2);
        expect(requests.last, requests.first);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
