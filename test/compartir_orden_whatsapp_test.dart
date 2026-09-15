import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportegutierrez/modules/ordenes_escolta/compartir_orden_whatsapp.dart';
import 'package:transportegutierrez/services/contacto_escolta.dart';

void main() {
  testWidgets(
    'iPhone prepara el PDF automáticamente una sola vez',
    (tester) async {
      var llamadas = 0;
      final pdf = Uint8List.fromList([37, 80, 68, 70, 45]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CompartirOrdenWhatsapp(
                automatico: true,
                pdf: pdf,
                mensaje: 'Orden C123-1',
                nombreArchivo: 'orden_C123-1.pdf',
                cargarContacto: () async =>
                    ContactoEscolta.fromJson({'destino': '+573223509469'}),
                compartir: (bytes, mensaje, nombre, origen) async {
                  llamadas++;
                  expect(bytes, pdf);
                  expect(mensaje, 'Orden C123-1');
                  expect(nombre, 'orden_C123-1.pdf');
                  expect(origen.width, greaterThan(0));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      expect(llamadas, 1);
      expect(find.textContaining('el PDF ya va adjunto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  test('el destinatario es independiente del celular de usuario', () {
    expect(normalizarCelular('314 467 2648'), '+573144672648');
    final uri = chatWhatsapp('+573223509469', 'Orden 36\nMáquina & destino');
    expect(uri.path, '/573223509469');
    expect(uri.queryParameters['text'], 'Orden 36\nMáquina & destino');
    expect(() => chatWhatsapp('', 'orden'), throwsStateError);
  });

  testWidgets(
    'comparte PDF y texto una vez ante doble toque, sin afirmar entrega',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<void>();
      var count = 0;
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CompartirOrdenWhatsapp(
                pdf: bytes,
                mensaje: 'Orden 36',
                nombreArchivo: 'orden_36.pdf',
                cargarContacto: () async => ContactoEscolta.fromJson({
                  'nombre': 'WILMER',
                  'whatsapp': null,
                  'destino': '+573223509469',
                  'placas': ['ABC123'],
                }),
                compartir: (pdf, text, name, origin) {
                  count++;
                  expect(pdf, bytes);
                  expect(text, 'Orden 36');
                  expect(name, 'orden_36.pdf');
                  return pending.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Destino: +573223509469'), findsOneWidget);
      await tester.tap(find.text('Abrir PDF en WhatsApp'));
      await tester.tap(find.text('Abrir PDF en WhatsApp'));
      await tester.pump();
      expect(count, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('no puede verificar su entrega'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fallo de configuración permite recuperar solo WhatsApp', (
    tester,
  ) async {
    var attempt = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompartirOrdenWhatsapp(
            pdf: Uint8List(1),
            mensaje: 'Orden',
            nombreArchivo: 'orden.pdf',
            cargarContacto: () async {
              if (++attempt == 1) throw StateError('sin conexión');
              return ContactoEscolta.fromJson({'destino': '+573223509469'});
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reintentar WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text('Destino: +573223509469'), findsOneWidget);
    expect(attempt, 2);
  });
}
