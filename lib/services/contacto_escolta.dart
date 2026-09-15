import 'api_service.dart';

String normalizarCelular(String value) {
  var digits = value.replaceAll(RegExp(r'[\s()+-]'), '');
  if (RegExp(r'^3\d{9}$').hasMatch(digits)) digits = '57$digits';
  return digits.isEmpty ? '' : '+$digits';
}

String? validarCelular(String? value) {
  final phone = normalizarCelular(value ?? '');
  return phone.isEmpty || RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)
      ? null
      : 'Ingrese un celular válido con código de país.';
}

class ContactoEscolta {
  final String nombre;
  final String? whatsapp;
  final String destino;
  final List<String> placas;
  ContactoEscolta.fromJson(Map<String, dynamic> json)
    : nombre = json['nombre']?.toString() ?? '',
      whatsapp = json['whatsapp']?.toString(),
      destino = json['destino']?.toString() ?? '',
      placas = List<String>.from(json['placas'] ?? []);

  static Future<ContactoEscolta> cargar({String? usuario}) async =>
      ContactoEscolta.fromJson(
        await ApiService.contactoEscolta(usuario: usuario),
      );
}

Uri chatWhatsapp(String destino, String mensaje) {
  if (destino.isEmpty || validarCelular(destino) != null) {
    throw StateError('Administración debe configurar el destino de WhatsApp.');
  }
  return Uri.https('wa.me', normalizarCelular(destino).substring(1), {
    'text': mensaje,
  });
}
