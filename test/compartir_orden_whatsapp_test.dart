import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportegutierrez/modules/ordenes_escolta/compartir_orden_whatsapp.dart';

void main() {
  testWidgets(
    'iPhone espera a que termine la transición para compartir',
    (tester) async {
      var llamadas = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: CompartirOrdenWhatsapp(
                        pdf: Uint8List(5),
                        mensaje: 'Orden',
                        nombreArchivo: 'orden.pdf',
                        automatico: true,
                        compartir: (_, _, _, _) async {
                          llamadas++;
                        },
                      ),
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(llamadas, 0);
      await tester.pumpAndSettle();
      expect(llamadas, 1);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
  final pdf = Uint8List.fromList([37, 80, 68, 70, 45]);
  Widget screen({
    bool automatico = false,
    Future<void> Function(Uint8List, String, String)? directo,
    required Future<void> Function(Uint8List, String, String, Rect) compartir,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CompartirOrdenWhatsapp(
          pdf: pdf,
          mensaje: 'Orden C123-1',
          nombreArchivo: 'orden_C123-1.pdf',
          automatico: automatico,
          abrirDirecto: directo,
          compartir: compartir,
        ),
      ),
    ),
  );

  testWidgets(
    'iPhone adjunta PDF automáticamente sin consultar destinatario',
    (tester) async {
      var llamadas = 0;
      await tester.pumpWidget(
        screen(
          automatico: true,
          compartir: (bytes, mensaje, nombre, origen) async {
            llamadas++;
            expect(bytes, pdf);
            expect(mensaje, 'Orden C123-1');
            expect(nombre, 'orden_C123-1.pdf');
            expect(origen.width, greaterThan(0));
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(llamadas, 1);
      expect(find.textContaining('Destino:'), findsNothing);
      expect(find.textContaining('el PDF ya va adjunto'), findsOneWidget);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'Android usa selector con el adjunto si falla apertura directa',
    (tester) async {
      var directos = 0;
      var selectores = 0;
      await tester.pumpWidget(
        screen(
          automatico: true,
          directo: (_, _, _) async {
            directos++;
            throw StateError('WhatsApp no resoluble');
          },
          compartir: (bytes, mensaje, nombre, origen) async {
            selectores++;
            expect(bytes, pdf);
            expect(mensaje, 'Orden C123-1');
            expect(nombre, 'orden_C123-1.pdf');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(directos, 1);
      expect(selectores, 1);
      expect(find.textContaining('No se pudo'), findsNothing);
      expect(find.textContaining('Destino:'), findsNothing);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'doble toque no repite apertura y selector permite reintentar',
    (tester) async {
      var count = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        screen(
          directo: (_, _, _) {
            count++;
            return pending.future;
          },
          compartir: (_, _, _, _) async {
            count++;
          },
        ),
      );
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
      await tester.tap(find.text('Compartir PDF y detalles'));
      await tester.pumpAndSettle();
      expect(count, 2);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
