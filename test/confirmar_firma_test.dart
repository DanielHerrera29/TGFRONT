import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transportegutierrez/modules/ordenes_escolta/borrador_orden.dart';
import 'package:transportegutierrez/modules/ordenes_escolta/screens/confirmar_firma_dialog.dart';

void main() {
  testWidgets(
    'recupera firmante y solicitud sin conservar ni aceptar código incompleto',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final draft = await BorradorOrden.load('otp-user', nueva: true);
      draft.state['firmaOtp'] = {
        'nombre': 'Ingeniero prueba',
        'email': 'arquitecto@gmail.com',
        'id': 'challenge',
      };
      await draft.persist();
      final restored = await BorradorOrden.load(
        'otp-user',
        orderId: draft.state['clientOrderId'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmarFirmaDialog(
              token: 'test',
              ordenId: 'order',

              draft: restored,
            ),
          ),
        ),
      );
      expect(find.text('Ingeniero prueba'), findsOneWidget);
      expect(find.text('arquitecto@gmail.com'), findsWidgets);
      await tester.tap(find.text('Validar código'));
      await tester.pump();
      expect(find.text('Ingrese los seis dígitos.'), findsOneWidget);
      expect((restored.state['firmaOtp'] as Map).containsKey('codigo'), false);
      expect(tester.takeException(), isNull);
    },
  );
}
