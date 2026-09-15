import 'package:flutter/services.dart';

class WhatsappPdfAndroid {
  static const channel = MethodChannel('teg/whatsapp_pdf');
  static Future<void> abrir(Uint8List pdf, String mensaje, String nombre) =>
      channel.invokeMethod<void>('abrirPdf', {
        'pdf': pdf,
        'mensaje': mensaje,
        'nombre': nombre,
      });
}
