import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:transportegutierrez/services/whatsapp_pdf_android.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android prepara el adjunto y abre WhatsApp sin enviar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Prueba de adjunto. NO ENVIAR en WhatsApp.'),
          ),
        ),
      ),
    );
    final doc = pw.Document()
      ..addPage(
        pw.Page(
          build: (_) => pw.Text(
            'PRUEBA TEG - NO ENVIAR\nOrden C123-1\nDocumento sintetico, sin datos operativos.',
          ),
        ),
      );
    final pdf = await doc.save();
    await expectLater(
      WhatsappPdfAndroid.abrir(pdf, 'Prueba', '../invalido.pdf'),
      throwsA(isA<PlatformException>()),
    );
    await WhatsappPdfAndroid.abrir(
      pdf,
      'PRUEBA TEG - NO ENVIAR. Verificar que WhatsApp recibe este PDF.',
      'prueba_teg_C123-1.pdf',
    );
    // El retorno comprueba la apertura de la actividad. No equivale a entrega.
  });
}
