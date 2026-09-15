import 'vehiculo.dart';

class Cliente {
  final String id;
  final String tipoCliente;
  final String nombre;
  final String? razonSocial;
  final String documento;
  final String? telefono;
  final bool activo;
  final List<VehiculoListItem> vehiculos;

  const Cliente({required this.id, required this.tipoCliente, required this.nombre, this.razonSocial, required this.documento, this.telefono, required this.activo, this.vehiculos = const []});

  factory Cliente.fromMap(Map<String, dynamic> m) => Cliente(
    id: m['id'].toString(), tipoCliente: m['tipo_cliente']?.toString() ?? 'empresa',
    nombre: m['nombre']?.toString() ?? '', razonSocial: m['razon_social']?.toString(),
    documento: m['nit_o_documento']?.toString() ?? '', telefono: m['telefono']?.toString(),
    activo: m['activo'] != false,
    vehiculos: ((m['cliente_vehiculos'] as List?) ?? const []).where((r) => (r as Map)['activo'] != false && r['vehiculos'] != null).map((r) {
      final v = Map<String, dynamic>.from((r as Map)['vehiculos'] as Map);
      return VehiculoListItem.fromMap(v);
    }).toList(),
  );
}
